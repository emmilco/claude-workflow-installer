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

### Installation (Two Steps)

The workflow system has two parts: **global installation** (one-time) and **per-project setup**.

#### Step 1: Global Installation (One-Time)

Install the workflow system globally so it's available to all your projects:

```bash
# Clone or download this workflow package
cd /path/to/workflow_installer

# Run global installer
bash install.sh
```

This installs:
- Claude Code skill to `~/.claude/skills/multi-agent-workflow.md`
- Workflow files to `~/.claude/skills/multi-agent-workflow/`
- Checks for required dependencies (jq, git, python3)

#### Step 2: Per-Project Setup

For each project where you want to use the workflow:

```bash
# Navigate to your project
cd /path/to/your/project

# Run project setup script
bash /path/to/workflow_installer/scripts/setup_project.sh
```

Or manually:
```bash
cd /path/to/your/project

# Create directory structure
mkdir -p .workflow/{scripts,prompts,hooks,templates,monitoring,evidence}
mkdir -p .workflow/scripts/{core,worktree,evolution}
mkdir -p .workflow/prompts/archive
mkdir -p worktrees

# Copy files from global installation
cp -r ~/.claude/skills/multi-agent-workflow/scripts/* .workflow/scripts/
cp -r ~/.claude/skills/multi-agent-workflow/prompts/* .workflow/prompts/
cp -r ~/.claude/skills/multi-agent-workflow/hooks/* .workflow/hooks/
cp -r ~/.claude/skills/multi-agent-workflow/templates/* .workflow/templates/

# Make executable
find .workflow/scripts -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +

# Initialize state files
touch TASKS.jsonl
cat > IN_PROGRESS.md <<'EOF'
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
EOF

# Add to .gitignore
cat >> .gitignore <<'EOF'
# Multi-Agent Workflow
TASKS.jsonl
IN_PROGRESS.md
.tasks.lock
worktrees/
.workflow/evidence/
.workflow/monitoring/
EOF

# Commit
git add .workflow .gitignore IN_PROGRESS.md
git commit -m "Set up multi-agent workflow"
```

#### Validate Setup

```bash
bash scripts/validate_system.sh
```

This checks:
- Required dependencies installed
- Directory structure correct
- Scripts executable
- State files valid

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

**Required:**
- Python 3.7+
- Git 2.25+ (for worktree support)
- Bash shell
- **jq** (for JSON processing in shell scripts)

To install jq:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Fedora/RHEL
sudo dnf install jq
```

**Optional:**
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

Add workflow health checks to your CI pipeline that fail the build if issues are detected:

```yaml
# .github/workflows/workflow-health.yml
name: Workflow Health Check

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.x'

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq

      - name: Validate workflow setup
        run: |
          if [ -f "scripts/validate_system.sh" ]; then
            bash scripts/validate_system.sh
          else
            echo "⚠ Validation script not found, skipping"
          fi

      - name: Check workflow health
        id: health_check
        run: |
          python3 .workflow/scripts/evolution/self_healing_monitor.py > health_output.txt
          cat health_output.txt

          # Extract health score (if available)
          if grep -q "Health score:" health_output.txt; then
            HEALTH_SCORE=$(grep "Health score:" health_output.txt | awk '{print $3}')
            echo "health_score=$HEALTH_SCORE" >> $GITHUB_OUTPUT

            # Fail if health score is below threshold
            if (( $(echo "$HEALTH_SCORE < 0.6" | bc -l) )); then
              echo "❌ Health score $HEALTH_SCORE is below threshold (0.6)"
              exit 1
            fi
          fi

      - name: Check for stale tasks
        run: |
          STALE_COUNT=$(python3 .workflow/scripts/core/task_manager.py detect-stale | wc -l)
          echo "Stale tasks: $STALE_COUNT"

          if [ "$STALE_COUNT" -gt 5 ]; then
            echo "❌ Too many stale tasks ($STALE_COUNT > 5)"
            exit 1
          fi

      - name: Check for orphaned worktrees
        run: |
          if [ -d "worktrees" ]; then
            FS_WORKTREES=$(ls -1 worktrees/ 2>/dev/null | wc -l || echo 0)
            TRACKED_WORKTREES=$(grep "TASK-" IN_PROGRESS.md 2>/dev/null | wc -l || echo 0)

            ORPHANED=$((FS_WORKTREES - TRACKED_WORKTREES))
            echo "Orphaned worktrees: $ORPHANED"

            if [ "$ORPHANED" -gt 3 ]; then
              echo "❌ Too many orphaned worktrees ($ORPHANED > 3)"
              exit 1
            fi
          fi

      - name: Upload dashboard
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: workflow-health-dashboard
          path: |
            .workflow/monitoring/DASHBOARD.md
            .workflow/monitoring/health-*.json
          retention-days: 30

      - name: Comment on PR (if health issues)
        if: failure() && github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ Workflow health check failed. Please review the workflow system health before merging.'
            })
```

**Key improvements:**
- ✅ Fails build if health score < 0.6
- ✅ Fails if too many stale tasks (>5)
- ✅ Fails if too many orphaned worktrees (>3)
- ✅ Runs validation script
- ✅ Comments on PRs with health issues
- ✅ Uploads dashboard as artifact

**Alternative: Fail on any workflow errors**

```yaml
      - name: Check workflow health (strict)
        run: |
          # Run monitor and capture exit code
          python3 .workflow/scripts/evolution/self_healing_monitor.py --strict

          # --strict flag makes monitor exit 1 if any issues detected
          # Add this to self_healing_monitor.py to enable
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

## Documentation

- **[README.md](README.md)** (this file) - Complete usage guide
- **[QUICK_START.md](QUICK_START.md)** - 10-minute getting started guide
- **[SKILL.md](SKILL.md)** - Claude Code skill documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical internals and design decisions
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and recovery procedures
- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - How to test the workflow system
- **[EXAMPLES.md](EXAMPLES.md)** - Complete walkthroughs with sample data
- **[MIGRATION.md](MIGRATION.md)** - Upgrade guide and version history

## Changelog

### v3.1.0 (2025-11-23)

**Critical Fixes:**
- Fixed path errors in SKILL.md:336 and spawn_agent.sh:116
- Added file locking for atomic task claiming (prevents race conditions)
- Added automatic project root detection (works from worktrees)
- Added worktree cleanup on claim failure
- Added jq dependency check in install.sh

**New Features:**
- Automated project setup script (`scripts/setup_project.sh`)
- System validation script (`scripts/validate_system.sh`)
- Comprehensive troubleshooting guide
- Complete testing guide with unit/integration/stress tests
- Detailed examples with actual data walkthrough
- Migration guide for upgrades

**New Documentation:**
- ARCHITECTURE.md - Technical internals, design decisions, cost considerations
- TROUBLESHOOTING.md - Common issues, failure scenarios, recovery procedures
- TESTING_GUIDE.md - How to test the workflow system itself
- EXAMPLES.md - Concrete walkthroughs with sample TASKS.jsonl entries
- MIGRATION.md - Upgrade guide and version history

**Improvements:**
- Clarified "agent spawning" terminology (workspace setup, not automation)
- Added cost warnings for parallel agents ($6-180/day for 6 agents)
- Redesigned SHA256 verification strategy (handles non-determinism)
- Complete task state model documentation (including rejected state)
- Security considerations documented
- Integrator vs Tester role distinction clarified
- Task cards directory purpose documented
- Installation process reconciled (global vs per-project)
- CI/CD integration now fails builds on health issues
- Improved error messages throughout

**Technical Improvements:**
- File locking prevents double-claim race conditions
- Project root auto-detection from worktrees
- Worktree cleanup on error
- Better error handling in all scripts
- Validation script checks full system health

### v3.0.0 (2025-11-23)

**Initial release:**
- Git worktree isolation
- Task state management (TASKS.jsonl)
- Evidence-based verification
- Self-healing monitor
- Prompt evolution system
- Six specialized roles (Architect, Implementer, Reviewer, Integrator, Tester, Monitor)
- Role prompts (~200-400 lines each)
- Comprehensive documentation
