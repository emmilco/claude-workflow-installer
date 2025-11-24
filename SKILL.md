---
name: "multi-agent-workflow"
description: >
  Orchestrates a multi-agent software engineering workflow with isolated git worktrees,
  evidence-based verification, self-healing monitoring, and prompt evolution.
  Supports architect, implementer, reviewer, integrator, tester, and monitor roles.
version: "3.0.0"
author: "Multi-Agent Workflow Team"
triggers:
  - "workflow"
  - "multi-agent"
  - "task management"
  - "spawn agent"
  - "create task"
  - "agent coordination"
  - "worktree workflow"
---

# Multi-Agent Workflow Skill

This skill enables structured multi-agent collaboration on software projects using:
- **Git worktrees** for isolated agent workspaces
- **Role-based agents** (Architect, Implementer, Reviewer, Integrator, Tester, Monitor)
- **Evidence-based verification** with SHA256 hashing and independent re-execution
- **Self-healing** automated cleanup of stale tasks and orphaned worktrees
- **Self-updating** prompt evolution based on empirical performance data

## When to Use This Skill

This skill activates when you discuss:
- Setting up or managing a multi-agent workflow
- Creating, claiming, or completing tasks
- Spawning agents for specific roles
- Reviewing agent performance
- Monitoring workflow health
- Evolving role prompts based on outcomes

## Template Files Location

All workflow template files (scripts, prompts, hooks, templates) are installed globally at:
```
~/.claude/skills/multi-agent-workflow/
├── scripts/
│   ├── core/
│   ├── worktree/
│   ├── ci/
│   └── evolution/
├── prompts/
├── hooks/
└── templates/
```

When setting up a project, copy files from this location to the project's `.workflow/` directory.

## Core Concepts

### 1. Task-Based Workflow

All work is organized into discrete tasks stored in `TASKS.jsonl`:
- Each task has a unique ID, description, role assignment, and acceptance criteria
- Tasks progress through states: `available` → `claimed` → `completed`
- Tasks are claimed by agents and worked on in isolated worktrees

### 2. Git Worktrees for Isolation

Each agent works in a separate worktree:
- Prevents file conflicts between parallel agents
- Changes stay isolated until reviewed and approved
- Failed work is abandoned without affecting main branch
- Clean merges via reviewer approval

### 3. Evidence-Based Verification

Quality is ensured through evidence:
- Implementers create claims with test results and SHA256 hashes
- Integrators independently re-execute tests to verify claims
- Divergence between claimed and actual results triggers investigation
- All evidence preserved for audit

### 4. Self-Healing

System automatically recovers from common issues:
- Stale tasks (claimed >2h with no activity) are auto-released
- Orphaned worktrees are detected and cleaned up
- Monitor tracks health metrics and triggers alerts
- Auto-remediation for known failure patterns

### 5. Self-Updating

Workflow improves itself over time:
- Analyzes completed tasks for patterns
- Identifies common failure modes by role
- Proposes prompt improvements based on empirical data
- Tracks prompt evolution with versioning

## Available Commands

### Task Management

```bash
# Create a new task
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Task title" \
  --description "Description" \
  --role "implementer" \
  --priority "medium"

# List all tasks
python3 .workflow/scripts/core/task_manager.py list-tasks

# List tasks by status
python3 .workflow/scripts/core/task_manager.py list-tasks --status available

# Get next available task for a role
python3 .workflow/scripts/core/task_manager.py get-next-task --role implementer

# Detect stale tasks
python3 .workflow/scripts/core/task_manager.py detect-stale

# Force release a stuck task
python3 .workflow/scripts/core/task_manager.py force-release --task-id TASK-001 --reason "stuck"
```

### Agent Workflow

```bash
# Spawn an agent for a role
bash .workflow/scripts/worktree/spawn_agent.sh architect
bash .workflow/scripts/worktree/spawn_agent.sh implementer
bash .workflow/scripts/worktree/spawn_agent.sh reviewer

# From within a worktree - submit for review
bash .workflow/scripts/worktree/submit_for_review.sh TASK-001

# Spawn reviewer for a specific task
bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-001

# Complete a review
bash .workflow/scripts/worktree/complete_review.sh TASK-001 approved "Looks good"
bash .workflow/scripts/worktree/complete_review.sh TASK-001 rejected "Needs fixes"
```

### Monitoring & Evolution

```bash
# Run self-healing monitor (one-time)
python3 .workflow/scripts/evolution/self_healing_monitor.py

# Run monitor in daemon mode
python3 .workflow/scripts/evolution/self_healing_monitor.py --daemon --interval 3600

# View health dashboard
cat .workflow/monitoring/DASHBOARD.md

# Analyze task outcomes for prompt improvements
python3 .workflow/scripts/evolution/evolve_prompts.py analyze

# Propose improvements for a specific role
python3 .workflow/scripts/evolution/evolve_prompts.py propose --role implementer

# Auto-apply basic improvements (use with caution)
python3 .workflow/scripts/evolution/evolve_prompts.py apply --role implementer --auto

# Archive a prompt version
python3 .workflow/scripts/evolution/evolve_prompts.py archive --role implementer
```

## Role Descriptions

### Architect
- Designs system architecture
- Breaks down features into implementable tasks
- Documents decisions with rationale
- Assesses risks and proposes mitigations

### Implementer
- Implements code for assigned tasks
- Writes comprehensive tests
- Creates evidence of successful implementation
- Submits work for review

### Reviewer
- Evaluates code quality and correctness
- Verifies test coverage and quality
- Checks adherence to architecture and standards
- Approves or rejects with detailed feedback

### Integrator
- Independently re-executes implementer tests
- Verifies evidence claims via SHA256 comparison
- Detects non-deterministic tests and environment issues
- Ensures reproducibility before merge

### Tester
- Runs comprehensive integration and E2E tests
- Validates performance and security
- Performs regression testing
- Provides detailed test evidence

### Monitor
- Collects workflow health metrics
- Detects anomalies and degraded performance
- Triggers alerts when thresholds breached
- Provides data for prompt evolution

## File Structure

After installation, your project will have:

```
.
├── TASKS.jsonl                 # All tasks (available, claimed, completed)
├── IN_PROGRESS.md              # Human-readable view of active work
├── DECISIONS.md                # Architectural decision log
├── worktrees/                  # Agent working directories
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
│   │   └── archive/          # Versioned old prompts
│   ├── hooks/
│   │   ├── pre_tool_use.sh
│   │   └── stop_gate.sh
│   ├── templates/
│   │   ├── task_card.template.yaml
│   │   ├── review_report.template.json
│   │   ├── decision_log.template.md
│   │   └── implementer_claim.template.json
│   ├── evidence/
│   │   ├── TASK-001/
│   │   │   ├── implementer_claim.json
│   │   │   ├── changes.diff
│   │   │   ├── test_output.txt
│   │   │   └── review/
│   │   │       └── review_report.json
│   │   └── TASK-002/
│   ├── monitoring/
│   │   ├── health-TIMESTAMP.json
│   │   ├── alert-TIMESTAMP.json
│   │   ├── DASHBOARD.md
│   │   └── evolution-log.md
│   └── task_cards/            # Optional: task templates
└── .claude/
    └── skills/
        └── multi-agent-workflow.md  # This skill
```

## Typical Workflow

### 1. Setup (One-time per project)

When setting up the workflow in a new project, copy the template files:

```bash
# Navigate to your project
cd /path/to/your/project

# Create workflow directory structure
mkdir -p .workflow/{scripts,prompts,hooks,templates,monitoring,evidence,task_cards}
mkdir -p .workflow/scripts/{core,worktree,ci,evolution}
mkdir -p .workflow/prompts/archive
mkdir -p worktrees

# Copy template files from global installation
cp -r ~/.claude/skills/multi-agent-workflow/scripts/* .workflow/scripts/
cp -r ~/.claude/skills/multi-agent-workflow/prompts/* .workflow/prompts/
cp -r ~/.claude/skills/multi-agent-workflow/hooks/* .workflow/hooks/
cp -r ~/.claude/skills/multi-agent-workflow/templates/* .workflow/templates/

# Make scripts executable
find .workflow/scripts -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
find .workflow/hooks -type f -name "*.sh" -exec chmod +x {} +

# Initialize state files
touch TASKS.jsonl

cat > IN_PROGRESS.md <<'EOF'
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
EOF

cat > DECISIONS.md <<'EOF'
# Decision Log

All architectural and implementation decisions are recorded here with evidence and rationale.

---
EOF

# Create initial tasks (as Architect)
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Implement user authentication" \
  --description "Add JWT-based auth" \
  --role "implementer"
```

### 2. Spawn Implementer
```bash
# Spawn an implementer agent
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Agent claims TASK-001 and gets worktree
# Output: cd worktrees/TASK-001
```

### 3. Work in Worktree
```bash
cd worktrees/TASK-001

# Implement the feature
# Write tests
# Commit changes

# Submit for review
bash .workflow/scripts/worktree/submit_for_review.sh TASK-001
```

### 4. Review Process

The reviewer workflow has three phases: setup, examination, and decision.

#### Phase 1: Setup
```bash
# Back in main repo (not in worktree)
cd ../../

# Spawn reviewer - loads evidence and prepares review context
bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-001
```

#### Phase 2: Examination

Reviewers work in the **implementer's worktree** to examine the actual code:

```bash
# Navigate to the implementer's worktree
cd worktrees/TASK-001

# Review the code changes
git diff main

# Examine evidence
cat ../../.workflow/evidence/TASK-001/implementer_claim.json

# Re-run tests to verify
pytest tests/ --randomly-seed=42

# Return to main repo
cd ../../
```

#### Phase 3: Decision

```bash
# Approve (merges to main)
bash .workflow/scripts/worktree/complete_review.sh TASK-001 approved "Great work"

# OR reject (returns task to available)
bash .workflow/scripts/worktree/complete_review.sh TASK-001 rejected "Needs fixes"
```

### 5. Monitor Health
```bash
# Check system health
python3 .workflow/scripts/evolution/self_healing_monitor.py

# View dashboard
cat .workflow/monitoring/DASHBOARD.md
```

### 6. Improve Over Time
```bash
# Analyze outcomes
python3 .workflow/scripts/evolution/evolve_prompts.py analyze

# Review suggestions
python3 .workflow/scripts/evolution/evolve_prompts.py propose --role implementer

# Apply improvements
# (manually edit prompts based on proposals)
```

## Configuration

### Concurrency Limit

Edit `.workflow/scripts/core/task_manager.py`:
```python
self.max_concurrent = 6  # Change to your desired limit
```

### Stale Threshold

Edit `.workflow/scripts/core/task_manager.py`:
```python
self.stale_threshold_hours = 2  # Change threshold
```

### Monitoring Interval

```bash
# Run monitor hourly (cron)
0 * * * * cd /path/to/repo && python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Best Practices

1. **Start Small**: Begin with 2-3 agents, not 6-8
2. **Monitor Health**: Run monitor regularly to catch issues early
3. **Review Evidence**: Don't skip evidence review - it catches bugs
4. **Evolve Prompts**: Use empirical data to improve role prompts
5. **Clean Worktrees**: Let the system auto-cleanup, don't manually remove
6. **Document Decisions**: Use DECISIONS.md for architectural choices
7. **Trust the Process**: Follow the workflow even when it feels slow initially

## Troubleshooting

### Issue: Stale tasks accumulating
**Solution**: Run monitor to auto-cleanup:
```bash
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

### Issue: Orphaned worktrees taking disk space
**Solution**: Monitor detects and removes them automatically

### Issue: Tests failing in re-execution but passed for implementer
**Solution**: Tests are non-deterministic. Fix randomness/timing issues.

### Issue: Low approval rate for a role
**Solution**: Analyze with evolution system:
```bash
python3 .workflow/scripts/evolution/evolve_prompts.py analyze
python3 .workflow/scripts/evolution/evolve_prompts.py propose --role <role>
```

### Issue: High queue depth, low utilization
**Solution**: Check if tasks require specific roles that no agents are filling

## Integration with Claude Code

This skill integrates with Claude Code's features:
- **Hooks**: PreToolUse and Stop hooks enforce workflow rules
- **Skills**: Role prompts guide agent behavior
- **Subagents**: Can spawn specialized agents for each role
- **Tools**: Uses Read, Write, Bash for file operations and task management

## Advanced Usage

### Parallel Agents

Run multiple agents in parallel:
```bash
# Terminal 1
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Terminal 2
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Terminal 3
bash .workflow/scripts/worktree/spawn_agent.sh reviewer
```

### Custom Roles

Add new role prompts in `.workflow/prompts/custom_role.md` and reference in task creation.

### CI/CD Integration

Use task manager in CI:
```yaml
# .github/workflows/test.yml
- name: Check workflow health
  run: python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Support & Documentation

- Full README: `docs/README.md`
- Role prompts: `.workflow/prompts/*.md`
- Examples: `.workflow/templates/*.template.*`
- Evolution log: `.workflow/monitoring/evolution-log.md`
- Health dashboard: `.workflow/monitoring/DASHBOARD.md`

## License

This workflow system is provided as-is for use in software projects.
