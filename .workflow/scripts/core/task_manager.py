#!/usr/bin/env python3
"""
Task Manager - Core state machine for multi-agent workflow

Handles task claiming, releasing, state tracking, and self-healing.
"""

import json
import argparse
import hashlib
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, List, Dict, Any
import subprocess
import sys


class TaskManager:
    """Manages task lifecycle and agent coordination"""

    def __init__(self, root_dir: Path = None):
        self.root_dir = root_dir or Path.cwd()
        self.tasks_file = self.root_dir / "TASKS.jsonl"
        self.in_progress_file = self.root_dir / "IN_PROGRESS.md"
        self.decisions_file = self.root_dir / "DECISIONS.md"
        self.worktrees_dir = self.root_dir / "worktrees"
        self.max_concurrent = 6
        self.stale_threshold_hours = 2

        # Ensure files exist
        self.tasks_file.touch(exist_ok=True)
        self.worktrees_dir.mkdir(exist_ok=True)

    def _read_tasks(self) -> List[Dict[str, Any]]:
        """Read all tasks from TASKS.jsonl"""
        if not self.tasks_file.exists():
            return []
        tasks = []
        with open(self.tasks_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    tasks.append(json.loads(line))
        return tasks

    def _write_task(self, task: Dict[str, Any]):
        """Append or update task in TASKS.jsonl"""
        tasks = self._read_tasks()

        # Remove existing task with same ID
        tasks = [t for t in tasks if t['task_id'] != task['task_id']]
        tasks.append(task)

        # Rewrite entire file (ensures consistency)
        with open(self.tasks_file, 'w') as f:
            for t in tasks:
                f.write(json.dumps(t) + '\n')

    def _read_in_progress(self) -> List[Dict[str, Any]]:
        """Parse IN_PROGRESS.md table"""
        if not self.in_progress_file.exists():
            return []

        content = self.in_progress_file.read_text()
        lines = content.split('\n')

        in_progress = []
        for line in lines:
            if line.startswith('|') and 'TASK-' in line:
                parts = [p.strip() for p in line.split('|')[1:-1]]
                if len(parts) >= 6:
                    try:
                        in_progress.append({
                            'task_id': parts[0],
                            'agent_id': parts[1],
                            'role': parts[2],
                            'claimed_at': datetime.fromisoformat(parts[3]),
                            'worktree_path': parts[4],
                            'status': parts[5]
                        })
                    except (ValueError, IndexError):
                        continue

        return in_progress

    def _update_in_progress(self, in_progress: List[Dict[str, Any]]):
        """Rewrite IN_PROGRESS.md with current state"""
        content = """# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
"""
        for item in in_progress:
            claimed_at = item['claimed_at'].isoformat() if isinstance(item['claimed_at'], datetime) else item['claimed_at']
            content += f"| {item['task_id']} | {item['agent_id']} | {item['role']} | {claimed_at} | {item['worktree_path']} | {item['status']} |\n"

        self.in_progress_file.write_text(content)

    def create_task(self, title: str, description: str, role: str = "any",
                   priority: str = "medium", files_in_scope: List[str] = None) -> str:
        """Create a new task"""
        task_id = self._generate_task_id(title)

        task = {
            "task_id": task_id,
            "title": title,
            "description": description,
            "role": role,
            "status": "available",
            "priority": priority,
            "files_in_scope": files_in_scope or ["**/*"],
            "acceptance_criteria": [
                "unit_tests pass",
                "integration_smoke pass",
                "reviewer approval"
            ],
            "created_at": datetime.now().isoformat(),
            "claimed_by": None,
            "claimed_at": None,
            "completed_at": None,
            "worktree_path": None
        }

        self._write_task(task)
        return task_id

    def _generate_task_id(self, title: str) -> str:
        """Generate unique task ID from title and timestamp"""
        timestamp = datetime.now().strftime('%Y%m%d')
        hash_suffix = abs(hash(title + str(datetime.now()))) % 10000
        return f"TASK-{timestamp}-{hash_suffix:04d}"

    def claim_task(self, task_id: str, agent_id: str, role: str) -> Optional[str]:
        """
        Claim a task for an agent.
        Returns worktree path if successful, None if failed.
        """
        # Check concurrency limit
        in_progress = self._read_in_progress()
        if len(in_progress) >= self.max_concurrent:
            print(f"ERROR: At maximum concurrency ({self.max_concurrent})", file=sys.stderr)
            return None

        # Check if task exists and is available
        tasks = self._read_tasks()
        task = next((t for t in tasks if t['task_id'] == task_id), None)

        if not task:
            print(f"ERROR: Task {task_id} not found", file=sys.stderr)
            return None

        if task['status'] != 'available':
            print(f"ERROR: Task {task_id} is not available (status: {task['status']})", file=sys.stderr)
            return None

        # Create worktree
        worktree_path = self.worktrees_dir / task_id
        try:
            subprocess.run(
                ['git', 'worktree', 'add', str(worktree_path), '-b', f'task/{task_id}'],
                check=True,
                capture_output=True
            )
        except subprocess.CalledProcessError as e:
            print(f"ERROR: Failed to create worktree: {e.stderr.decode()}", file=sys.stderr)
            return None

        # Update task status
        task['status'] = 'claimed'
        task['claimed_by'] = agent_id
        task['claimed_at'] = datetime.now().isoformat()
        task['worktree_path'] = str(worktree_path)
        self._write_task(task)

        # Add to IN_PROGRESS.md
        in_progress.append({
            'task_id': task_id,
            'agent_id': agent_id,
            'role': role,
            'claimed_at': datetime.now(),
            'worktree_path': str(worktree_path),
            'status': 'in_progress'
        })
        self._update_in_progress(in_progress)

        return str(worktree_path)

    def complete_task(self, task_id: str, verdict: str, review_notes: str = "") -> bool:
        """
        Complete a task with verdict: 'approved' or 'rejected'
        Returns True if successful
        """
        if verdict not in ['approved', 'rejected']:
            print(f"ERROR: Invalid verdict '{verdict}'. Must be 'approved' or 'rejected'", file=sys.stderr)
            return False

        tasks = self._read_tasks()
        task = next((t for t in tasks if t['task_id'] == task_id), None)

        if not task:
            print(f"ERROR: Task {task_id} not found", file=sys.stderr)
            return False

        if task['status'] != 'claimed':
            print(f"ERROR: Task {task_id} is not claimed (status: {task['status']})", file=sys.stderr)
            return False

        worktree_path = Path(task['worktree_path'])

        if verdict == 'approved':
            # Merge to main
            try:
                # Return to main repo
                subprocess.run(['git', 'checkout', 'main'], check=True, capture_output=True)
                subprocess.run(
                    ['git', 'merge', '--no-ff', f'task/{task_id}', '-m',
                     f'Merge task {task_id}: {task["title"]}\n\n{review_notes}'],
                    check=True,
                    capture_output=True
                )
                task['status'] = 'completed'
                task['completed_at'] = datetime.now().isoformat()
                print(f"✓ Task {task_id} merged to main")
            except subprocess.CalledProcessError as e:
                print(f"ERROR: Failed to merge: {e.stderr.decode()}", file=sys.stderr)
                return False
        else:
            # Rejected - just mark as available again
            task['status'] = 'available'
            task['claimed_by'] = None
            task['claimed_at'] = None
            task['worktree_path'] = None
            print(f"✗ Task {task_id} rejected and returned to available tasks")

        # Remove worktree
        try:
            subprocess.run(
                ['git', 'worktree', 'remove', str(worktree_path), '--force'],
                check=True,
                capture_output=True
            )
        except subprocess.CalledProcessError as e:
            print(f"Warning: Failed to remove worktree: {e.stderr.decode()}", file=sys.stderr)

        # Update task
        self._write_task(task)

        # Remove from IN_PROGRESS.md
        in_progress = self._read_in_progress()
        in_progress = [t for t in in_progress if t['task_id'] != task_id]
        self._update_in_progress(in_progress)

        return True

    def get_next_task(self, role: str = None) -> Optional[Dict[str, Any]]:
        """Get next available task, optionally filtered by role"""
        tasks = self._read_tasks()
        available = [t for t in tasks if t['status'] == 'available']

        if role:
            available = [t for t in available if t['role'] in [role, 'any']]

        if not available:
            return None

        # Sort by priority: high > medium > low
        priority_order = {'high': 0, 'medium': 1, 'low': 2}
        available.sort(key=lambda t: priority_order.get(t.get('priority', 'medium'), 1))

        return available[0]

    def detect_stale_tasks(self) -> List[Dict[str, Any]]:
        """Find tasks claimed >2 hours ago with no recent activity"""
        in_progress = self._read_in_progress()
        stale = []

        for task_info in in_progress:
            claimed_at = task_info['claimed_at']
            if isinstance(claimed_at, str):
                claimed_at = datetime.fromisoformat(claimed_at)

            age = datetime.now() - claimed_at
            if age > timedelta(hours=self.stale_threshold_hours):
                # Check for recent activity in worktree
                worktree = Path(task_info['worktree_path'])
                if not self._has_recent_activity(worktree):
                    stale.append(task_info)

        return stale

    def _has_recent_activity(self, worktree: Path, minutes: int = 30) -> bool:
        """Check if worktree has files modified in last N minutes"""
        if not worktree.exists():
            return False

        threshold = datetime.now().timestamp() - (minutes * 60)

        for file in worktree.rglob('*'):
            if file.is_file() and not '.git' in str(file):
                if file.stat().st_mtime > threshold:
                    return True

        return False

    def force_release(self, task_id: str, reason: str = "stale") -> bool:
        """Force release a stale or stuck task"""
        tasks = self._read_tasks()
        task = next((t for t in tasks if t['task_id'] == task_id), None)

        if not task:
            return False

        # Log decision
        self._log_decision(
            f"FORCE-RELEASE-{task_id}",
            f"Force released task {task_id}",
            f"Task was {reason} and needed cleanup",
            "self-healing monitor"
        )

        # Remove worktree if exists
        if task.get('worktree_path'):
            worktree_path = Path(task['worktree_path'])
            if worktree_path.exists():
                try:
                    subprocess.run(
                        ['git', 'worktree', 'remove', str(worktree_path), '--force'],
                        check=True,
                        capture_output=True
                    )
                except subprocess.CalledProcessError:
                    pass

        # Reset task to available
        task['status'] = 'available'
        task['claimed_by'] = None
        task['claimed_at'] = None
        task['worktree_path'] = None
        self._write_task(task)

        # Remove from IN_PROGRESS.md
        in_progress = self._read_in_progress()
        in_progress = [t for t in in_progress if t['task_id'] != task_id]
        self._update_in_progress(in_progress)

        return True

    def _log_decision(self, decision_id: str, title: str, rationale: str, owner: str):
        """Append to DECISIONS.md"""
        entry = f"""
## {datetime.now().isoformat()} | {decision_id}
**Owner:** {owner}
**Decision:** {title}
**Rationale:** {rationale}

---
"""
        with open(self.decisions_file, 'a') as f:
            f.write(entry)

    def list_tasks(self, status: str = None) -> List[Dict[str, Any]]:
        """List all tasks, optionally filtered by status"""
        tasks = self._read_tasks()
        if status:
            tasks = [t for t in tasks if t['status'] == status]
        return tasks

    def get_task(self, task_id: str) -> Optional[Dict[str, Any]]:
        """Get specific task by ID"""
        tasks = self._read_tasks()
        return next((t for t in tasks if t['task_id'] == task_id), None)


def main():
    parser = argparse.ArgumentParser(description='Task Manager CLI')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # create-task
    create = subparsers.add_parser('create-task', help='Create a new task')
    create.add_argument('--title', required=True, help='Task title')
    create.add_argument('--description', required=True, help='Task description')
    create.add_argument('--role', default='any', help='Required role (architect, implementer, etc.)')
    create.add_argument('--priority', default='medium', choices=['low', 'medium', 'high'])

    # claim-task
    claim = subparsers.add_parser('claim-task', help='Claim a task')
    claim.add_argument('--task-id', required=True, help='Task ID to claim')
    claim.add_argument('--agent-id', required=True, help='Agent ID claiming the task')
    claim.add_argument('--role', required=True, help='Agent role')

    # complete-task
    complete = subparsers.add_parser('complete-task', help='Complete a task')
    complete.add_argument('--task-id', required=True, help='Task ID')
    complete.add_argument('--verdict', required=True, choices=['approved', 'rejected'])
    complete.add_argument('--notes', default='', help='Review notes')

    # get-next-task
    get_next = subparsers.add_parser('get-next-task', help='Get next available task')
    get_next.add_argument('--role', help='Filter by role')

    # list-tasks
    list_cmd = subparsers.add_parser('list-tasks', help='List tasks')
    list_cmd.add_argument('--status', help='Filter by status')

    # detect-stale
    subparsers.add_parser('detect-stale', help='Detect stale tasks')

    # force-release
    force = subparsers.add_parser('force-release', help='Force release a task')
    force.add_argument('--task-id', required=True, help='Task ID')
    force.add_argument('--reason', default='manual', help='Reason for release')

    args = parser.parse_args()

    tm = TaskManager()

    if args.command == 'create-task':
        task_id = tm.create_task(args.title, args.description, args.role, args.priority)
        print(json.dumps({"task_id": task_id, "status": "created"}))

    elif args.command == 'claim-task':
        worktree = tm.claim_task(args.task_id, args.agent_id, args.role)
        if worktree:
            print(json.dumps({"task_id": args.task_id, "worktree": worktree, "status": "claimed"}))
            sys.exit(0)
        else:
            sys.exit(1)

    elif args.command == 'complete-task':
        success = tm.complete_task(args.task_id, args.verdict, args.notes)
        sys.exit(0 if success else 1)

    elif args.command == 'get-next-task':
        task = tm.get_next_task(args.role)
        if task:
            print(json.dumps(task, indent=2))
        else:
            print(json.dumps({"error": "No available tasks"}))
            sys.exit(1)

    elif args.command == 'list-tasks':
        tasks = tm.list_tasks(args.status)
        print(json.dumps(tasks, indent=2))

    elif args.command == 'detect-stale':
        stale = tm.detect_stale_tasks()
        print(json.dumps(stale, indent=2, default=str))

    elif args.command == 'force-release':
        success = tm.force_release(args.task_id, args.reason)
        sys.exit(0 if success else 1)

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
