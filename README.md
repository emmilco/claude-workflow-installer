# Multi-Agent Workflow System v3

A production-ready, self-healing, self-updating multi-agent workflow system for software engineering teams using Claude Code.

## Features

- ✅ **Git Worktree Isolation** - Each agent works in a separate worktree, preventing file conflicts
- ✅ **Evidence-Based Verification** - SHA256 hashing and independent re-execution validate all claims
- ✅ **Self-Healing** - Automatic cleanup of stale tasks and orphaned worktrees
- ✅ **Self-Updating** - Prompt evolution based on empirical performance data
- ✅ **Role-Based Agents** - Specialized prompts for Architect, Implementer, Reviewer, Integrator, Tester, Monitor
- ✅ **Task Management** - Full lifecycle tracking from creation to completion
- ✅ **Health Monitoring** - Real-time metrics and alerts for workflow health
- ✅ **Portable** - Easy installation into any git repository

## Quick Start

### Installation

```bash
# Clone or download this workflow package
cd /path/to/your/project

# Run installer
bash /path/to/workflow_v3/install.sh .
```

This will:
1. Create `.workflow/` directory with all scripts and prompts
2. Set up `TASKS.jsonl`, `IN_PROGRESS.md`, and `DECISIONS.md`
3. Install the Claude Code skill
4. Configure hooks (optional)

### Create Your First Task

```bash
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Add user authentication" \
  --description "Implement JWT-based authentication for API" \
  --role "implementer" \
  --priority "high"
```

### Spawn an Agent

```bash
# This will claim the next available task and create a worktree
bash .workflow/scripts/worktree/spawn_agent.sh implementer
```

### Work in Worktree

```bash
# Agent will output the worktree path
cd worktrees/TASK-XXXXXXXX-XXXX

# Do your work
# Write code, add tests, commit changes

# When done, submit for review
bash .workflow/scripts/worktree/submit_for_review.sh TASK-XXXXXXXX-XXXX
```

### Review and Merge

```bash
# Back in main repo
cd ../../

# Spawn reviewer
bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-XXXXXXXX-XXXX

# Reviewer examines evidence and code, then:
bash .workflow/scripts/worktree/complete_review.sh TASK-XXXXXXXX-XXXX approved "LGTM"
```

Done! The work is merged to main and the worktree is cleaned up.

## Architecture

### Core Components

1. **Task Manager** (`scripts/core/task_manager.py`)
   - Creates, claims, releases, and completes tasks
   - Manages worktree lifecycle
   - Detects stale tasks
   - Enforces concurrency limits (default: 6)

2. **Worktree Scripts** (`scripts/worktree/`)
   - `spawn_agent.sh` - Claim task and create worktree
   - `submit_for_review.sh` - Package evidence and signal ready
   - `spawn_reviewer.sh` - Start review process
   - `complete_review.sh` - Approve/reject and merge/cleanup

3. **Self-Healing Monitor** (`scripts/evolution/self_healing_monitor.py`)
   - Collects health metrics
   - Detects anomalies
   - Auto-remediates common issues
   - Generates alerts and dashboard

4. **Prompt Evolution** (`scripts/evolution/evolve_prompts.py`)
   - Analyzes task outcomes
   - Identifies patterns in failures
   - Proposes prompt improvements
   - Tracks prompt versions

5. **Role Prompts** (`prompts/*.md`)
   - Specialized instructions for each agent type
   - Guides behavior and output format
   - Evolves based on empirical data

6. **Hooks** (`hooks/*.sh`)
   - `pre_tool_use.sh` - Prevents dangerous operations
   - `stop_gate.sh` - Lightweight validation after responses

### Workflow Diagram

```
[Architect]
    ↓ creates tasks
[TASKS.jsonl] ← available tasks
    ↓ claimed by
[Implementer] in worktree/TASK-001
    ↓ submits evidence
[Evidence Package] (SHA256 hash)
    ↓ reviewed by
[Reviewer] examines code + tests
    ↓ if approved
[Integrator] re-executes tests
    ↓ if verified
[MERGE to main]
    ↓ cleanup
[Worktree removed]
    ↓ continuous
[Monitor] tracks health
    ↓ improves
[Prompt Evolution]
```

## Role Descriptions

### Architect
**Purpose:** System design and task breakdown
**Outputs:** design_spec.yaml, task cards, decision logs
**Skills:** Architecture patterns, risk assessment, task decomposition

### Implementer
**Purpose:** Write code to complete tasks
**Outputs:** Code, tests, evidence package
**Skills:** Coding, testing, documentation

### Reviewer
**Purpose:** Quality gate before merging
**Outputs:** Review report, verdict (approved/rejected)
**Skills:** Code review, security analysis, style checking

### Integrator
**Purpose:** Independent verification
**Outputs:** Independent evidence, divergence reports
**Skills:** Test execution, determinism validation

### Tester
**Purpose:** Comprehensive quality validation
**Outputs:** Integration test results, performance data
**Skills:** E2E testing, performance testing, contract testing

### Monitor
**Purpose:** System health and continuous improvement
**Outputs:** Health metrics, alerts, dashboards
**Skills:** Metrics analysis, anomaly detection, auto-remediation

## Key Workflows

### Parallel Development

Run multiple agents simultaneously:

```bash
# Terminal 1
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Terminal 2
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Terminal 3
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# All work in parallel without conflicts thanks to worktrees
```

### Continuous Monitoring

```bash
# One-time health check
python3 .workflow/scripts/evolution/self_healing_monitor.py

# Continuous monitoring (daemon mode)
python3 .workflow/scripts/evolution/self_healing_monitor.py --daemon --interval 3600

# View dashboard anytime
cat .workflow/monitoring/DASHBOARD.md
```

### Prompt Improvement

```bash
# Analyze what's working and what's not
python3 .workflow/scripts/evolution/evolve_prompts.py analyze

# Get specific suggestions for a role
python3 .workflow/scripts/evolution/evolve_prompts.py propose --role implementer

# Review the proposal manually and update prompts
# Or auto-apply basic improvements (use with caution)
python3 .workflow/scripts/evolution/evolve_prompts.py apply --role implementer --auto
```

## Configuration

### Adjust Concurrency Limit

Edit `.workflow/scripts/core/task_manager.py`:

```python
self.max_concurrent = 6  # Change to 4, 8, etc.
```

### Adjust Stale Threshold

Edit `.workflow/scripts/core/task_manager.py`:

```python
self.stale_threshold_hours = 2  # Change to 1, 4, etc.
```

### Custom Role Prompts

Create new file in `.workflow/prompts/custom_role.md` with your specialized instructions.

## File Structure

```
your-project/
├── TASKS.jsonl                # Task database
├── IN_PROGRESS.md             # Active work tracking
├── DECISIONS.md               # Architecture decisions
├── worktrees/                 # Agent workspaces
│   ├── TASK-001/
│   └── TASK-002/
├── .workflow/
│   ├── scripts/
│   │   ├── core/
│   │   │   └── task_manager.py
│   │   ├── worktree/
│   │   │   ├── spawn_agent.sh
│   │   │   ├── submit_for_review.sh
│   │   │   ├── spawn_reviewer.sh
│   │   │   └── complete_review.sh
│   │   └── evolution/
│   │       ├── self_healing_monitor.py
│   │       └── evolve_prompts.py
│   ├── prompts/
│   │   ├── architect.md
│   │   ├── implementer.md
│   │   ├── reviewer.md
│   │   ├── integrator.md
│   │   ├── tester.md
│   │   ├── monitor.md
│   │   └── archive/
│   ├── hooks/
│   ├── templates/
│   ├── evidence/
│   ├── monitoring/
│   │   ├── health-*.json
│   │   ├── alert-*.json
│   │   ├── DASHBOARD.md
│   │   └── evolution-log.md
│   └── task_cards/
└── .claude/
    └── skills/
        └── multi-agent-workflow.md
```

## Requirements

- Python 3.7+
- Git 2.25+ (for worktree support)
- Bash shell
- jq (for JSON processing in shell scripts)

Optional:
- pytest (for Python projects)
- npm (for JavaScript projects)

## Troubleshooting

### "git worktree add" fails

**Cause:** Git version too old or not in a git repo
**Solution:** Upgrade git to 2.25+ or ensure you're in a git repository

### Stale tasks accumulating

**Cause:** Agents crashed or were stopped without cleanup
**Solution:** Run monitor to auto-cleanup:
```bash
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

### Tests pass for implementer but fail for integrator

**Cause:** Non-deterministic tests (randomness, timing, external dependencies)
**Solution:** Fix tests to be deterministic:
- Use fixed random seeds
- Mock external services
- Control time (use freezegun or similar)
- Ensure test isolation

### Low approval rate

**Cause:** Role prompt may not provide adequate guidance
**Solution:** Use evolution system:
```bash
python3 .workflow/scripts/evolution/evolve_prompts.py analyze
python3 .workflow/scripts/evolution/evolve_prompts.py propose --role <role>
```

### Permission denied on scripts

**Cause:** Scripts not executable
**Solution:** Make scripts executable:
```bash
find .workflow/scripts -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
```

## Best Practices

1. **Start Small** - Begin with 2-3 agents, not 6-8
2. **Monitor Regularly** - Run health checks daily
3. **Trust the Evidence** - Don't skip verification steps
4. **Evolve Prompts** - Use data to improve role performance
5. **Document Decisions** - Use DECISIONS.md for architecture choices
6. **Keep Tasks Focused** - Aim for 2-6 hour completion time
7. **Review Promptly** - Don't let tasks sit in review for days

## Advanced Topics

### CI/CD Integration

Add to your CI pipeline:

```yaml
# .github/workflows/workflow-health.yml
name: Workflow Health Check

on: [push, schedule]

jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Check Workflow Health
        run: python3 .workflow/scripts/evolution/self_healing_monitor.py
      - name: Upload Dashboard
        uses: actions/upload-artifact@v2
        with:
          name: health-dashboard
          path: .workflow/monitoring/DASHBOARD.md
```

### Custom Metrics

Extend `self_healing_monitor.py` to track project-specific metrics:

```python
def collect_custom_metrics(self):
    # Add your metrics
    return {
        'code_coverage': self._get_coverage(),
        'technical_debt': self._measure_debt(),
        'security_score': self._run_security_scan()
    }
```

### Integration with External Tools

- **Jira:** Create tasks from Jira issues
- **Slack:** Post alerts to Slack channels
- **Prometheus:** Export metrics for monitoring
- **DataDog:** Send health metrics to DataDog

## Examples

See `docs/examples/` for:
- Complete task workflow walkthrough
- Setting up for different project types (Python, JavaScript, Go, etc.)
- Integrating with existing CI/CD
- Custom role creation

## Support

For issues, questions, or contributions:
- Check troubleshooting section above
- Review role prompts in `.workflow/prompts/`
- Examine monitoring dashboard for insights
- Check evolution log for prompt changes

## License

This workflow system is provided as-is for use in software projects.

## Changelog

### v3.0.0 (2025-11-23)
- Initial release with all core features
- Git worktree isolation
- Evidence-based verification
- Self-healing monitor
- Prompt evolution system
- Six specialized roles
- Comprehensive documentation
