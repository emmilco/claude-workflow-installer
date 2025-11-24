#!/usr/bin/env python3
"""
Self-Healing Monitor

Continuously monitors workflow health, detects issues, and auto-remediates where possible.
"""

import sys
import json
import time
import argparse
import statistics
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

sys.path.insert(0, str(Path(__file__).parent.parent / 'core'))
from task_manager import TaskManager


class SelfHealingMonitor:
    """Monitors workflow health and performs auto-remediation"""

    def __init__(self, root_dir: Path = None):
        self.root_dir = root_dir or Path.cwd()
        self.tm = TaskManager(self.root_dir)
        self.monitoring_dir = self.root_dir / '.workflow' / 'monitoring'
        self.monitoring_dir.mkdir(parents=True, exist_ok=True)

    def collect_metrics(self) -> Dict[str, Any]:
        """Collect current workflow metrics"""
        tasks = self.tm.list_tasks()
        in_progress = self.tm._read_in_progress()

        # Basic counts
        total_tasks = len(tasks)
        completed = [t for t in tasks if t['status'] == 'completed']
        available = [t for t in tasks if t['status'] == 'available']
        claimed = [t for t in tasks if t['status'] == 'claimed']

        # Completion rate
        completion_rate = len(completed) / total_tasks if total_tasks > 0 else 0

        # Cycle times
        cycle_times = []
        for task in completed:
            if task.get('created_at') and task.get('completed_at'):
                created = datetime.fromisoformat(task['created_at'])
                completed_at = datetime.fromisoformat(task['completed_at'])
                cycle_times.append((completed_at - created).total_seconds())

        median_cycle_time = statistics.median(cycle_times) if cycle_times else 0
        p95_cycle_time = statistics.quantiles(cycle_times, n=20)[18] if len(cycle_times) > 20 else median_cycle_time

        # Stale tasks
        stale_tasks = self.tm.detect_stale_tasks()

        # Queue depth
        queue_depth = len(available)

        # Worktree utilization
        worktree_utilization = len(in_progress) / self.tm.max_concurrent

        # Check for orphaned worktrees
        orphaned_worktrees = self._find_orphaned_worktrees()

        metrics = {
            'timestamp': datetime.now().isoformat(),
            'total_tasks': total_tasks,
            'completed_tasks': len(completed),
            'available_tasks': len(available),
            'claimed_tasks': len(claimed),
            'completion_rate': completion_rate,
            'median_cycle_time_seconds': median_cycle_time,
            'p95_cycle_time_seconds': p95_cycle_time,
            'stale_task_count': len(stale_tasks),
            'queue_depth': queue_depth,
            'worktree_utilization': worktree_utilization,
            'orphaned_worktree_count': len(orphaned_worktrees),
            'active_agents': len(in_progress)
        }

        return metrics

    def _find_orphaned_worktrees(self) -> List[str]:
        """Find worktrees not tracked in IN_PROGRESS.md"""
        worktrees_dir = self.root_dir / 'worktrees'
        if not worktrees_dir.exists():
            return []

        # Get worktrees from filesystem
        fs_worktrees = set(d.name for d in worktrees_dir.iterdir() if d.is_dir())

        # Get worktrees from IN_PROGRESS
        in_progress = self.tm._read_in_progress()
        tracked_worktrees = set(Path(t['worktree_path']).name for t in in_progress)

        orphaned = list(fs_worktrees - tracked_worktrees)
        return orphaned

    def compute_health_score(self, metrics: Dict[str, Any]) -> float:
        """Compute 0-1 system health score"""

        # Component scores (0-1)
        completion_score = min(metrics['completion_rate'] / 0.8, 1.0)

        # Ideal cycle time: 4 hours (14400 seconds)
        ideal_cycle_time = 14400
        cycle_time_score = min(ideal_cycle_time / max(metrics['median_cycle_time_seconds'], 1), 1.0)

        # Stale tasks bad
        stale_score = max(0, 1.0 - (metrics['stale_task_count'] / 5))

        # Utilization optimal at 70-90%
        util = metrics['worktree_utilization']
        if 0.7 <= util <= 0.9:
            util_score = 1.0
        elif util < 0.7:
            util_score = util / 0.7
        else:
            util_score = max(0, 1.0 - (util - 0.9) / 0.1)

        # Orphaned worktrees bad
        orphan_score = max(0, 1.0 - (metrics['orphaned_worktree_count'] / 3))

        # Weighted average
        health = (
            0.25 * completion_score +
            0.25 * cycle_time_score +
            0.20 * stale_score +
            0.15 * util_score +
            0.15 * orphan_score
        )

        return health

    def detect_anomalies(self, metrics: Dict[str, Any], historical: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Detect anomalies by comparing to historical baseline"""
        anomalies = []

        if len(historical) < 3:
            return anomalies  # Need baseline

        # Cycle time spike
        hist_cycle_times = [h['median_cycle_time_seconds'] for h in historical if h['median_cycle_time_seconds'] > 0]
        if hist_cycle_times:
            hist_median = statistics.median(hist_cycle_times)
            if metrics['median_cycle_time_seconds'] > hist_median * 1.5:
                anomalies.append({
                    'type': 'cycle_time_spike',
                    'severity': 'warning',
                    'message': f"Cycle time increased 50%: {hist_median:.0f}s -> {metrics['median_cycle_time_seconds']:.0f}s",
                    'baseline': hist_median,
                    'current': metrics['median_cycle_time_seconds']
                })

        # Completion rate drop
        hist_completion = [h['completion_rate'] for h in historical]
        if hist_completion:
            hist_avg = statistics.mean(hist_completion)
            if metrics['completion_rate'] < hist_avg * 0.7:
                anomalies.append({
                    'type': 'completion_drop',
                    'severity': 'warning',
                    'message': f"Completion rate dropped 30%: {hist_avg:.1%} -> {metrics['completion_rate']:.1%}",
                    'baseline': hist_avg,
                    'current': metrics['completion_rate']
                })

        return anomalies

    def generate_alerts(self, metrics: Dict[str, Any], health: float, anomalies: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Generate alerts based on metrics and anomalies"""
        alerts = []

        # Critical health
        if health < 0.6:
            alerts.append({
                'id': f"alert-health-{int(datetime.now().timestamp())}",
                'severity': 'critical',
                'type': 'system_health_low',
                'message': f"System health critically low: {health:.2f}",
                'recommendation': 'Review recent failures and agent performance',
                'auto_remediation': None
            })

        # High stale task count
        if metrics['stale_task_count'] > 2:
            alerts.append({
                'id': f"alert-stale-{int(datetime.now().timestamp())}",
                'severity': 'warning',
                'type': 'stale_tasks',
                'message': f"{metrics['stale_task_count']} stale tasks detected",
                'recommendation': 'Auto-cleanup will run',
                'auto_remediation': 'cleanup_stale_tasks'
            })

        # Orphaned worktrees
        if metrics['orphaned_worktree_count'] > 0:
            alerts.append({
                'id': f"alert-orphan-{int(datetime.now().timestamp())}",
                'severity': 'info',
                'type': 'orphaned_worktrees',
                'message': f"{metrics['orphaned_worktree_count']} orphaned worktrees found",
                'recommendation': 'Auto-cleanup will run',
                'auto_remediation': 'cleanup_orphaned_worktrees'
            })

        # High queue depth
        if metrics['queue_depth'] > 15:
            alerts.append({
                'id': f"alert-queue-{int(datetime.now().timestamp())}",
                'severity': 'info',
                'type': 'high_queue_depth',
                'message': f"Queue depth high: {metrics['queue_depth']} tasks waiting",
                'recommendation': 'Consider spawning more agents',
                'auto_remediation': None
            })

        # Low utilization
        if metrics['worktree_utilization'] < 0.3 and metrics['queue_depth'] > 0:
            alerts.append({
                'id': f"alert-util-{int(datetime.now().timestamp())}",
                'severity': 'info',
                'type': 'low_utilization',
                'message': f"Low utilization ({metrics['worktree_utilization']:.0%}) with {metrics['queue_depth']} tasks available",
                'recommendation': 'Tasks may require specific roles - check task/agent role alignment',
                'auto_remediation': None
            })

        # Add anomaly alerts
        for anomaly in anomalies:
            alerts.append({
                'id': f"alert-anomaly-{int(datetime.now().timestamp())}",
                'severity': anomaly['severity'],
                'type': anomaly['type'],
                'message': anomaly['message'],
                'auto_remediation': None
            })

        return alerts

    def auto_remediate(self, alerts: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Perform auto-remediation for alerts that support it"""
        actions_taken = {
            'cleanup_stale_tasks': 0,
            'cleanup_orphaned_worktrees': 0
        }

        for alert in alerts:
            action = alert.get('auto_remediation')

            if action == 'cleanup_stale_tasks':
                stale_tasks = self.tm.detect_stale_tasks()
                for task_info in stale_tasks:
                    success = self.tm.force_release(task_info['task_id'], reason='stale')
                    if success:
                        actions_taken['cleanup_stale_tasks'] += 1
                        print(f"  ✓ Released stale task: {task_info['task_id']}")

            elif action == 'cleanup_orphaned_worktrees':
                orphaned = self._find_orphaned_worktrees()
                for worktree_name in orphaned:
                    worktree_path = self.root_dir / 'worktrees' / worktree_name
                    try:
                        subprocess.run(
                            ['git', 'worktree', 'remove', str(worktree_path), '--force'],
                            check=True,
                            capture_output=True
                        )
                        actions_taken['cleanup_orphaned_worktrees'] += 1
                        print(f"  ✓ Removed orphaned worktree: {worktree_name}")
                    except subprocess.CalledProcessError as e:
                        print(f"  ✗ Failed to remove {worktree_name}: {e.stderr.decode()}")

        return actions_taken

    def load_historical_metrics(self, limit: int = 20) -> List[Dict[str, Any]]:
        """Load recent historical metrics"""
        metric_files = sorted(self.monitoring_dir.glob('health-*.json'))[-limit:]
        historical = []
        for f in metric_files:
            try:
                historical.append(json.loads(f.read_text()))
            except json.JSONDecodeError:
                continue
        return historical

    def save_report(self, metrics: Dict[str, Any], health: float, anomalies: List[Dict[str, Any]],
                   alerts: List[Dict[str, Any]], actions_taken: Dict[str, Any]):
        """Save monitoring report"""
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')

        report = {
            'timestamp': datetime.now().isoformat(),
            'metrics': metrics,
            'system_health': health,
            'anomalies': anomalies,
            'alerts': alerts,
            'auto_remediation': actions_taken
        }

        # Save main report
        report_file = self.monitoring_dir / f'health-{timestamp}.json'
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)

        print(f"\n✓ Saved report: {report_file}")

        # If alerts exist, also save alert file
        if alerts:
            alert_file = self.monitoring_dir / f'alert-{timestamp}.json'
            with open(alert_file, 'w') as f:
                json.dump({'timestamp': datetime.now().isoformat(), 'alerts': alerts}, f, indent=2)
            print(f"✓ Saved alerts: {alert_file}")

    def generate_dashboard(self, metrics: Dict[str, Any], health: float, alerts: List[Dict[str, Any]]):
        """Generate human-readable dashboard"""
        dashboard = f"""# Workflow Health Dashboard

**Last Updated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## System Health: {health:.2f} {'✅' if health > 0.8 else '⚠️' if health > 0.6 else '❌'}

### Key Metrics
- **Total Tasks:** {metrics['total_tasks']}
- **Completed:** {metrics['completed_tasks']} ({metrics['completion_rate']:.0%})
- **Available:** {metrics['available_tasks']}
- **In Progress:** {metrics['claimed_tasks']} ({metrics['worktree_utilization']:.0%} utilization)

### Performance
- **Median Cycle Time:** {metrics['median_cycle_time_seconds']/3600:.1f} hours
- **P95 Cycle Time:** {metrics['p95_cycle_time_seconds']/3600:.1f} hours
- **Queue Depth:** {metrics['queue_depth']} tasks
- **Active Agents:** {metrics['active_agents']}/{self.tm.max_concurrent}

### Health Indicators
- **Stale Tasks:** {metrics['stale_task_count']} {'✅' if metrics['stale_task_count'] == 0 else '⚠️'}
- **Orphaned Worktrees:** {metrics['orphaned_worktree_count']} {'✅' if metrics['orphaned_worktree_count'] == 0 else '⚠️'}
- **Utilization:** {metrics['worktree_utilization']:.0%} {'✅' if 0.7 <= metrics['worktree_utilization'] <= 0.9 else 'ℹ️'}

"""

        if alerts:
            dashboard += "### Active Alerts\n"
            for alert in alerts:
                icon = '❌' if alert['severity'] == 'critical' else '⚠️' if alert['severity'] == 'warning' else 'ℹ️'
                dashboard += f"- {icon} **{alert['type']}**: {alert['message']}\n"
        else:
            dashboard += "### Active Alerts\nNo alerts ✅\n"

        dashboard += "\n---\n*Auto-generated by Self-Healing Monitor*\n"

        # Save dashboard
        dashboard_file = self.monitoring_dir / 'DASHBOARD.md'
        with open(dashboard_file, 'w') as f:
            f.write(dashboard)

        return dashboard

    def run_monitoring_cycle(self):
        """Execute one complete monitoring cycle"""
        print("=" * 50)
        print("Self-Healing Monitor - Running")
        print("=" * 50)

        # 1. Collect metrics
        print("\n[1/6] Collecting metrics...")
        metrics = self.collect_metrics()

        # 2. Compute health
        print("[2/6] Computing health score...")
        health = self.compute_health_score(metrics)
        print(f"  System Health: {health:.2f}")

        # 3. Load historical and detect anomalies
        print("[3/6] Detecting anomalies...")
        historical = self.load_historical_metrics()
        anomalies = self.detect_anomalies(metrics, historical)
        if anomalies:
            print(f"  Found {len(anomalies)} anomalies")
        else:
            print("  No anomalies detected")

        # 4. Generate alerts
        print("[4/6] Generating alerts...")
        alerts = self.generate_alerts(metrics, health, anomalies)
        if alerts:
            print(f"  Generated {len(alerts)} alerts")
            for alert in alerts:
                icon = '❌' if alert['severity'] == 'critical' else '⚠️' if alert['severity'] == 'warning' else 'ℹ️'
                print(f"    {icon} {alert['message']}")
        else:
            print("  No alerts")

        # 5. Auto-remediate
        print("[5/6] Auto-remediation...")
        actions_taken = self.auto_remediate(alerts)
        if any(actions_taken.values()):
            print(f"  Cleaned {actions_taken['cleanup_stale_tasks']} stale tasks")
            print(f"  Removed {actions_taken['cleanup_orphaned_worktrees']} orphaned worktrees")
        else:
            print("  No remediation needed")

        # 6. Save reports
        print("[6/6] Saving reports...")
        self.save_report(metrics, health, anomalies, alerts, actions_taken)
        dashboard = self.generate_dashboard(metrics, health, alerts)
        print("\nDashboard Preview:")
        print("-" * 50)
        print(dashboard)
        print("-" * 50)

        print("\n" + "=" * 50)
        print(f"Monitoring cycle complete - Health: {health:.2f}")
        print("=" * 50)

        return health


def main():
    parser = argparse.ArgumentParser(description='Self-Healing Workflow Monitor')
    parser.add_argument('--daemon', action='store_true', help='Run continuously')
    parser.add_argument('--interval', type=int, default=3600, help='Interval in seconds (daemon mode)')
    parser.add_argument('--quick', action='store_true', help='Quick check only')

    args = parser.parse_args()

    monitor = SelfHealingMonitor()

    if args.daemon:
        print(f"Starting monitor daemon (interval: {args.interval}s)")
        print("Press Ctrl+C to stop")
        try:
            while True:
                monitor.run_monitoring_cycle()
                print(f"\nSleeping for {args.interval} seconds...")
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\nMonitor stopped by user")
            sys.exit(0)
    else:
        # Single run
        health = monitor.run_monitoring_cycle()
        sys.exit(0 if health > 0.6 else 1)


if __name__ == '__main__':
    main()
