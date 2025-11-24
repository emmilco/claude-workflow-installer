#!/usr/bin/env python3
"""
Prompt Evolution System

Analyzes task outcomes and suggests improvements to role prompts.
Enables self-updating workflow based on empirical performance data.
"""

import sys
import json
import argparse
import shutil
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent.parent / 'core'))
from task_manager import TaskManager


class PromptEvolutionSystem:
    """Analyzes outcomes and evolves role prompts"""

    def __init__(self, root_dir: Path = None):
        self.root_dir = root_dir or Path.cwd()
        self.tm = TaskManager(self.root_dir)
        self.prompts_dir = self.root_dir / '.workflow' / 'prompts'
        self.archive_dir = self.prompts_dir / 'archive'
        self.evolution_log = self.root_dir / '.workflow' / 'monitoring' / 'evolution-log.md'
        self.archive_dir.mkdir(parents=True, exist_ok=True)

    def analyze_task_outcomes(self) -> Dict[str, Any]:
        """Analyze completed tasks for patterns"""
        tasks = self.tm.list_tasks()
        completed = [t for t in tasks if t['status'] == 'completed']

        if not completed:
            return {'error': 'No completed tasks to analyze'}

        # Group by role
        by_role = defaultdict(list)
        for task in completed:
            role = task.get('role', 'any')
            by_role[role].append(task)

        analysis = {}

        for role, role_tasks in by_role.items():
            # Calculate metrics
            total = len(role_tasks)

            # Get cycle times
            cycle_times = []
            for task in role_tasks:
                if task.get('created_at') and task.get('completed_at'):
                    created = datetime.fromisoformat(task['created_at'])
                    completed_at = datetime.fromisoformat(task['completed_at'])
                    cycle_times.append((completed_at - created).total_seconds())

            avg_cycle_time = sum(cycle_times) / len(cycle_times) if cycle_times else 0

            # Check evidence directory for review patterns
            evidence_dir = self.root_dir / '.workflow' / 'evidence'
            rejected_count = 0
            common_issues = defaultdict(int)

            for task in role_tasks:
                task_evidence = evidence_dir / task['task_id']
                if task_evidence.exists():
                    review_file = task_evidence / 'review' / 'review_report.json'
                    if review_file.exists():
                        try:
                            review = json.loads(review_file.read_text())
                            if review.get('verdict') == 'rejected':
                                rejected_count += 1
                                # Categorize issues
                                for issue in review.get('issues', []):
                                    # Simple categorization - could be more sophisticated
                                    if 'test' in issue.lower():
                                        common_issues['testing'] += 1
                                    elif 'style' in issue.lower() or 'format' in issue.lower():
                                        common_issues['style'] += 1
                                    elif 'security' in issue.lower():
                                        common_issues['security'] += 1
                                    elif 'performance' in issue.lower():
                                        common_issues['performance'] += 1
                                    else:
                                        common_issues['other'] += 1
                        except (json.JSONDecodeError, KeyError):
                            pass

            approval_rate = (total - rejected_count) / total if total > 0 else 0

            analysis[role] = {
                'total_tasks': total,
                'avg_cycle_time_hours': avg_cycle_time / 3600,
                'approval_rate': approval_rate,
                'rejection_count': rejected_count,
                'common_issues': dict(common_issues)
            }

        return analysis

    def generate_improvement_suggestions(self, analysis: Dict[str, Any]) -> Dict[str, List[str]]:
        """Generate specific improvement suggestions based on analysis"""
        suggestions = {}

        for role, metrics in analysis.items():
            role_suggestions = []

            # Low approval rate
            if metrics['approval_rate'] < 0.8:
                role_suggestions.append(
                    f"Approval rate is {metrics['approval_rate']:.0%} (target: >80%). "
                    "Review common rejection reasons and add guidance to prompt."
                )

            # Long cycle times
            if metrics['avg_cycle_time_hours'] > 8:
                role_suggestions.append(
                    f"Average cycle time is {metrics['avg_cycle_time_hours']:.1f} hours (target: <8h). "
                    "Consider adding time management guidance or breaking tasks smaller."
                )

            # Common issues
            issues = metrics.get('common_issues', {})
            if issues.get('testing', 0) > 2:
                role_suggestions.append(
                    f"Testing issues found in {issues['testing']} tasks. "
                    "Add more detailed testing guidelines and examples to prompt."
                )

            if issues.get('style', 0) > 2:
                role_suggestions.append(
                    f"Style issues found in {issues['style']} tasks. "
                    "Add specific style guidelines and code examples to prompt."
                )

            if issues.get('security', 0) > 0:
                role_suggestions.append(
                    f"Security issues found in {issues['security']} tasks. "
                    "CRITICAL: Add security checklist and common vulnerability examples."
                )

            if issues.get('performance', 0) > 2:
                role_suggestions.append(
                    f"Performance issues found in {issues['performance']} tasks. "
                    "Add performance guidelines and profiling instructions."
                )

            if role_suggestions:
                suggestions[role] = role_suggestions

        return suggestions

    def propose_prompt_changes(self, role: str, current_prompt: str, suggestions: List[str]) -> str:
        """
        Propose specific changes to a role prompt.
        In a full implementation, this would use an LLM to generate refined prompts.
        For now, we provide structured suggestions.
        """

        proposal = f"""# Prompt Evolution Proposal for {role.title()}

## Current Performance Analysis

"""
        for i, suggestion in enumerate(suggestions, 1):
            proposal += f"{i}. {suggestion}\n"

        proposal += f"""

## Recommended Actions

### If Testing Issues:
Add a "Testing Checklist" section:
```markdown
### Testing Checklist
- [ ] Unit tests for all new functions
- [ ] Integration tests for cross-module functionality
- [ ] Edge cases covered (null, empty, boundary values)
- [ ] Tests use fixed seeds for determinism
- [ ] All tests pass locally before submission
```

### If Style Issues:
Add a "Code Style Standards" section with examples from the codebase.

### If Security Issues:
Add a "Security Checklist" section:
```markdown
### Security Checklist
- [ ] All user input validated and sanitized
- [ ] SQL queries use parameterized statements (no string concatenation)
- [ ] No sensitive data in logs
- [ ] Authentication/authorization checks present
- [ ] Dependencies up to date (no known vulnerabilities)
```

### If Performance Issues:
Add performance guidelines and profiling instructions.

### If Long Cycle Times:
Add time management guidance:
```markdown
### Time Management
- Read task requirements carefully (15 min)
- Design approach before coding (15 min)
- Implement incrementally with tests (2-4 hours)
- Review and refine (30 min)
- Submit for review (15 min)
Target: Complete within 4-6 hours
```

## Manual Review Required

This is an automated analysis. Please:
1. Review current prompt at: {self.prompts_dir}/{role}.md
2. Assess which suggestions are most impactful
3. Update prompt manually or use an LLM to refine it
4. Archive old version
5. Test with new prompt for 5-10 tasks
6. Measure improvement

## Auto-Apply (NOT RECOMMENDED)

To auto-apply basic improvements:
  python3 .workflow/scripts/evolution/evolve_prompts.py apply --role {role} --auto

This will add checklists but may not be contextually appropriate.
"""

        return proposal

    def archive_prompt(self, role: str) -> str:
        """Archive current version of a prompt"""
        current_prompt_file = self.prompts_dir / f'{role}.md'

        if not current_prompt_file.exists():
            return None

        # Create version identifier
        version = datetime.now().strftime('%Y%m%d-%H%M%S')
        archive_file = self.archive_dir / f'{role}-v{version}.md'

        # Copy to archive
        shutil.copy(current_prompt_file, archive_file)

        return str(archive_file)

    def log_evolution(self, role: str, reason: str, archived_version: str, changes: str):
        """Log prompt evolution to tracking file"""
        entry = f"""
## {datetime.now().isoformat()} | {role.upper()}-EVOLUTION

**Role:** {role}
**Reason:** {reason}
**Archived Version:** {archived_version}
**Changes Made:** {changes}

---
"""

        with open(self.evolution_log, 'a') as f:
            f.write(entry)

    def apply_basic_improvements(self, role: str, issues: List[str]) -> bool:
        """
        Apply basic template improvements to a prompt.
        This is a simplified auto-apply - real implementation should be more sophisticated.
        """
        prompt_file = self.prompts_dir / f'{role}.md'

        if not prompt_file.exists():
            print(f"Error: Prompt file not found: {prompt_file}")
            return False

        current_prompt = prompt_file.read_text()

        # Archive current version
        archived = self.archive_prompt(role)

        # Add sections based on issues
        additions = []

        if 'testing' in str(issues).lower():
            additions.append("""
## Testing Checklist (Added by Evolution)

Before submitting, ensure:
- [ ] Unit tests for all new functions
- [ ] Integration tests for cross-module functionality
- [ ] Edge cases covered (null, empty, boundary values)
- [ ] Tests use fixed seeds for determinism
- [ ] All tests pass locally
""")

        if 'security' in str(issues).lower():
            additions.append("""
## Security Checklist (Added by Evolution)

CRITICAL - Verify:
- [ ] All user input validated and sanitized
- [ ] SQL queries use parameterized statements
- [ ] No sensitive data in logs
- [ ] Authentication/authorization checks present
- [ ] Dependencies up to date
""")

        if additions:
            updated_prompt = current_prompt + "\n\n" + "\n".join(additions)
            prompt_file.write_text(updated_prompt)

            self.log_evolution(
                role,
                "Auto-applied improvements based on common issues",
                archived,
                f"Added {len(additions)} checklist sections"
            )

            return True

        return False


def main():
    parser = argparse.ArgumentParser(description='Prompt Evolution System')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # analyze
    subparsers.add_parser('analyze', help='Analyze task outcomes and suggest improvements')

    # propose
    propose = subparsers.add_parser('propose', help='Propose specific prompt changes')
    propose.add_argument('--role', required=True, help='Role to propose changes for')

    # apply
    apply_cmd = subparsers.add_parser('apply', help='Apply prompt improvements')
    apply_cmd.add_argument('--role', required=True, help='Role to update')
    apply_cmd.add_argument('--auto', action='store_true', help='Auto-apply basic improvements (use with caution)')

    # archive
    archive = subparsers.add_parser('archive', help='Archive a prompt version')
    archive.add_argument('--role', required=True, help='Role to archive')

    args = parser.parse_args()

    pes = PromptEvolutionSystem()

    if args.command == 'analyze':
        print("Analyzing task outcomes...")
        analysis = pes.analyze_task_outcomes()

        if 'error' in analysis:
            print(f"Error: {analysis['error']}")
            sys.exit(1)

        print("\n" + "=" * 60)
        print("ANALYSIS RESULTS")
        print("=" * 60)

        for role, metrics in analysis.items():
            print(f"\n## {role.upper()}")
            print(f"  Total Tasks: {metrics['total_tasks']}")
            print(f"  Approval Rate: {metrics['approval_rate']:.0%}")
            print(f"  Avg Cycle Time: {metrics['avg_cycle_time_hours']:.1f} hours")

            if metrics.get('common_issues'):
                print(f"  Common Issues:")
                for issue_type, count in metrics['common_issues'].items():
                    print(f"    - {issue_type}: {count}")

        print("\n" + "=" * 60)
        print("SUGGESTIONS")
        print("=" * 60)

        suggestions = pes.generate_improvement_suggestions(analysis)

        if not suggestions:
            print("\nNo improvements suggested - all roles performing well!")
        else:
            for role, role_suggestions in suggestions.items():
                print(f"\n## {role.upper()}")
                for i, suggestion in enumerate(role_suggestions, 1):
                    print(f"{i}. {suggestion}")

        print("\nTo see detailed proposals:")
        for role in suggestions.keys():
            print(f"  python3 .workflow/scripts/evolution/evolve_prompts.py propose --role {role}")

    elif args.command == 'propose':
        analysis = pes.analyze_task_outcomes()
        suggestions_all = pes.generate_improvement_suggestions(analysis)

        if args.role not in suggestions_all:
            print(f"No improvements suggested for role '{args.role}'")
            sys.exit(0)

        prompt_file = pes.prompts_dir / f'{args.role}.md'
        if not prompt_file.exists():
            print(f"Error: Prompt not found: {prompt_file}")
            sys.exit(1)

        current_prompt = prompt_file.read_text()
        suggestions = suggestions_all[args.role]

        proposal = pes.propose_prompt_changes(args.role, current_prompt, suggestions)
        print(proposal)

        # Save proposal
        proposal_file = pes.root_dir / '.workflow' / 'monitoring' / f'proposal-{args.role}-{datetime.now().strftime("%Y%m%d-%H%M%S")}.md'
        proposal_file.parent.mkdir(parents=True, exist_ok=True)
        proposal_file.write_text(proposal)
        print(f"\nProposal saved to: {proposal_file}")

    elif args.command == 'apply':
        if args.auto:
            print(f"Auto-applying improvements to {args.role} prompt...")
            print("WARNING: This is experimental. Review changes manually after.")

            analysis = pes.analyze_task_outcomes()
            suggestions_all = pes.generate_improvement_suggestions(analysis)

            if args.role not in suggestions_all:
                print(f"No improvements needed for {args.role}")
                sys.exit(0)

            success = pes.apply_basic_improvements(args.role, suggestions_all[args.role])

            if success:
                print(f"✓ Updated {args.role} prompt")
                print(f"  Old version archived to: {pes.archive_dir}")
                print(f"  Evolution logged to: {pes.evolution_log}")
                print("\nPlease review the changes and test with actual tasks.")
            else:
                print("Failed to apply improvements")
                sys.exit(1)
        else:
            print("Please apply changes manually after reviewing the proposal.")
            print("Or use --auto flag for automatic basic improvements (use with caution).")

    elif args.command == 'archive':
        archived = pes.archive_prompt(args.role)
        if archived:
            print(f"✓ Archived {args.role} prompt to: {archived}")
        else:
            print(f"Error: Prompt not found for role {args.role}")
            sys.exit(1)

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
