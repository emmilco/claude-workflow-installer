# Quick Start Guide

## Installation (2 minutes)

```bash
# From your project root
bash /path/to/workflow_v3/install.sh .

# Answer prompts:
# - Configure hooks? → y (recommended)
# - Install Python dependencies? → y (if using Python)
```

## First Task (5 minutes)

```bash
# 1. Create a task
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Add README section" \
  --description "Add installation instructions to README" \
  --role "implementer" \
  --priority "medium"

# 2. Spawn an implementer
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Output shows: cd worktrees/TASK-XXXXXXXX-XXXX

# 3. Go to worktree and work
cd worktrees/TASK-XXXXXXXX-XXXX
# Make your changes, write tests, commit

# 4. Submit for review
bash .workflow/scripts/worktree/submit_for_review.sh TASK-XXXXXXXX-XXXX
```

## Review (3 minutes)

```bash
# Back to main repo
cd ../../

# Spawn reviewer
bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-XXXXXXXX-XXXX

# Review the evidence and code
cat .workflow/evidence/TASK-XXXXXXXX-XXXX/changes.diff
cat .workflow/evidence/TASK-XXXXXXXX-XXXX/test_output.txt

# Complete review
bash .workflow/scripts/worktree/complete_review.sh TASK-XXXXXXXX-XXXX approved "Good work"
```

Done! Your work is merged and the worktree is cleaned up.

## Check Health

```bash
python3 .workflow/scripts/evolution/self_healing_monitor.py
cat .workflow/monitoring/DASHBOARD.md
```

## Common Commands

```bash
# List all tasks
python3 .workflow/scripts/core/task_manager.py list-tasks

# List available tasks
python3 .workflow/scripts/core/task_manager.py list-tasks --status available

# Check what's in progress
cat IN_PROGRESS.md

# View decisions
cat DECISIONS.md

# Monitor health (continuous)
python3 .workflow/scripts/evolution/self_healing_monitor.py --daemon --interval 3600
```

## Next Steps

1. Read the full [README.md](README.md)
2. Customize role prompts in `.workflow/prompts/`
3. Set up continuous monitoring
4. Start running parallel agents
5. Review the [SKILL.md](SKILL.md) for Claude Code integration

## Tips

- **Start with 2-3 agents**, not 6-8
- **Monitor daily** for the first week
- **Review evidence carefully** - it catches bugs early
- **Use the evolution system** after 10-20 completed tasks
- **Trust the process** - it feels slow at first but speeds up with practice

## Help

```bash
# Task manager help
python3 .workflow/scripts/core/task_manager.py --help

# Monitor help
python3 .workflow/scripts/evolution/self_healing_monitor.py --help

# Evolution help
python3 .workflow/scripts/evolution/evolve_prompts.py --help
```

## Troubleshooting

**Scripts not executable?**
```bash
chmod +x .workflow/scripts/**/*.sh .workflow/scripts/**/*.py
```

**No tasks available?**
```bash
# Create some tasks first!
python3 .workflow/scripts/core/task_manager.py create-task --title "..." --description "..." --role "implementer"
```

**Stale tasks?**
```bash
# Auto-cleanup with monitor
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Full Documentation

- [README.md](README.md) - Complete guide
- [SKILL.md](SKILL.md) - Claude Code skill documentation
- `.workflow/prompts/*.md` - Role-specific instructions
- `.workflow/templates/` - Template files
