---
name: "bootstrap-workflow"
description: >
  Installs the Multi-Agent Workflow System v3 into the current project.
  Sets up git worktrees, task management, self-healing monitoring, prompt evolution,
  and all role prompts for architect, implementer, reviewer, integrator, tester, and monitor.
  Use this skill once per project to set up the complete workflow infrastructure.
version: "3.0.0"
author: "Multi-Agent Workflow Team"
triggers:
  - "bootstrap workflow"
  - "install workflow"
  - "setup workflow"
  - "setup multi-agent workflow"
  - "install multi-agent"
  - "bootstrap multi-agent"
---

# Bootstrap Workflow Skill

This skill installs the complete Multi-Agent Workflow System v3 into your current project.

## When This Skill Activates

Say any of:
- "Bootstrap the workflow"
- "Install the multi-agent workflow"
- "Set up the workflow system"
- "Install workflow v3"

## What This Skill Does

When activated, I will:

1. **Verify Prerequisites**
   - Check you're in a git repository
   - Verify git version 2.25+
   - Check Python 3.7+ available
   - Confirm jq is installed

2. **Create Directory Structure**
   - `.workflow/` with all subdirectories
   - `TASKS.jsonl`, `IN_PROGRESS.md`, `DECISIONS.md`
   - `worktrees/` directory

3. **Install Core Scripts**
   - `task_manager.py` - Task lifecycle management
   - `self_healing_monitor.py` - Health monitoring and auto-remediation
   - `evolve_prompts.py` - Prompt evolution system
   - Worktree scripts (spawn, submit, review, complete)

4. **Install Role Prompts**
   - Architect, Implementer, Reviewer, Integrator, Tester, Monitor
   - Each with comprehensive guidelines and checklists

5. **Install Hooks**
   - PreToolUse hook (prevents dangerous operations)
   - Stop hook (lightweight validation)

6. **Install Templates**
   - Task cards, review reports, decision logs, evidence claims

7. **Configure Claude Code**
   - Install the multi-agent-workflow skill locally to the project
   - Optionally configure hooks in `.claude/settings.json`

## After Installation

You'll have a complete workflow system ready to use:

```bash
# Create your first task
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Your task" \
  --description "Description" \
  --role "implementer"

# Spawn an agent
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Monitor health
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Prerequisites Check

Before I install, I need:
- ✅ Git repository (will check with `git status`)
- ✅ Git 2.25+ (for worktree support)
- ✅ Python 3.7+
- ✅ jq command (for JSON processing in shell scripts)

If anything is missing, I'll let you know how to install it.

## Installation Options

I'll ask you:
1. **Configure hooks?** - Should I add PreToolUse and Stop hooks to `.claude/settings.json`?
2. **Install project skill?** - Should I install the multi-agent-workflow skill locally to this project?

## Usage After Bootstrap

Once installed, you can:

1. **Create tasks** (as Architect or manually)
2. **Spawn agents** for different roles
3. **Work in isolated worktrees** without conflicts
4. **Submit for review** with evidence packages
5. **Monitor health** and let the system self-heal
6. **Evolve prompts** based on outcomes

See `.workflow/README.md` for complete documentation after installation.

## Files This Skill Creates

```
your-project/
├── TASKS.jsonl
├── IN_PROGRESS.md
├── DECISIONS.md
├── worktrees/
├── .workflow/
│   ├── scripts/core/task_manager.py
│   ├── scripts/worktree/*.sh
│   ├── scripts/evolution/*.py
│   ├── prompts/*.md
│   ├── hooks/*.sh
│   ├── templates/*.{yaml,json,md}
│   ├── evidence/
│   └── monitoring/
└── .claude/
    ├── skills/multi-agent-workflow.md
    └── settings.json (if hooks configured)
```

## Reinstallation

If you've already installed, I'll ask if you want to:
- **Update** - Keep existing tasks/evidence, update scripts/prompts
- **Clean install** - Remove everything and reinstall fresh
- **Cancel** - Don't make any changes

## Support

After installation:
- Read `.workflow/README.md` for full documentation
- Check `.workflow/QUICK_START.md` for a guided tutorial
- Review role prompts in `.workflow/prompts/`
- Run monitor to see system health

Ready to bootstrap? Just say "bootstrap the workflow" and I'll get started!
