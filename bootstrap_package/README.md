# Bootstrap Workflow Package

This package installs the Multi-Agent Workflow System v3 as a global Claude Code skill.

## What This Is

A portable package you can download to any computer. Once installed, Claude Code gains a `bootstrap-workflow` skill that can install the complete workflow system into any project with a single command.

## Installation (One-Time Per Computer)

### Step 1: Download This Package

```bash
# Copy the entire workflow_v3 folder to your target computer
# Or clone from git if you've pushed it
```

### Step 2: Install the Bootstrap Skill Globally

```bash
cd workflow_v3/bootstrap_package
bash install_bootstrap.sh
```

This installs:
- The `bootstrap-workflow` skill to `~/.claude/skills/`
- All workflow assets to `~/.claude/workflow_assets/`

You only need to do this **once per computer**.

## Usage (In Any Project)

After installation, in any project:

### Method 1: Via Claude Code (Recommended)

```bash
# Go to your project
cd /path/to/your/project

# Start Claude Code
claude-code

# In Claude, say:
"bootstrap the workflow"
```

Claude will:
1. Check prerequisites (git, python, jq)
2. Ask for confirmation
3. Install the complete workflow system
4. Configure everything

### Method 2: Manual Bootstrap

```bash
cd /path/to/your/project
bash ~/.claude/workflow_assets/bootstrap.sh .
```

## What Gets Installed In Each Project

```
your-project/
├── TASKS.jsonl                 # Task database
├── IN_PROGRESS.md              # Active work tracking
├── DECISIONS.md                # Decision log
├── worktrees/                  # Agent workspaces
├── .workflow/
│   ├── scripts/
│   │   ├── core/task_manager.py
│   │   ├── worktree/*.sh
│   │   └── evolution/*.py
│   ├── prompts/*.md
│   ├── hooks/*.sh
│   ├── templates/
│   ├── evidence/
│   ├── monitoring/
│   ├── README.md
│   └── QUICK_START.md
└── .claude/
    ├── skills/multi-agent-workflow.md
    └── settings.json (optional)
```

## Quick Test

After installing the bootstrap skill:

```bash
# Create a test project
mkdir ~/test-workflow
cd ~/test-workflow
git init
git commit --allow-empty -m "Initial commit"

# Start Claude Code
claude-code

# Say to Claude:
"bootstrap the workflow"

# After installation, create a test task
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Test task" \
  --description "Verify workflow works" \
  --role "implementer"

# Spawn an agent
bash .workflow/scripts/worktree/spawn_agent.sh implementer
```

## Files In This Package

```
bootstrap_package/
├── README.md                    # This file
├── SKILL.md                     # The bootstrap-workflow skill
├── install_bootstrap.sh         # Global installer
└── USAGE.md                     # Detailed usage guide
```

## How It Works

1. **Global Installation**: `install_bootstrap.sh` copies:
   - The skill to `~/.claude/skills/bootstrap-workflow.md`
   - All workflow assets to `~/.claude/workflow_assets/`
   - A `bootstrap.sh` script that does the actual installation

2. **Skill Activation**: When you say "bootstrap the workflow" in Claude:
   - The skill is triggered
   - Claude reads the instructions in `SKILL.md`
   - Claude calls `~/.claude/workflow_assets/bootstrap.sh`
   - The script installs everything into your current project

3. **Per-Project Setup**: Each project gets:
   - Complete workflow infrastructure in `.workflow/`
   - State files (TASKS.jsonl, IN_PROGRESS.md, DECISIONS.md)
   - Local project skill for ongoing workflow support

## Prerequisites

The bootstrap script checks for:
- ✅ Git 2.25+ (for worktree support)
- ✅ Python 3.7+
- ✅ jq (JSON processor)
- ✅ Git repository initialized

If anything is missing, it provides installation instructions.

## Distribution

To share this with others:

### Option 1: Archive

```bash
cd workflow_v3
tar -czf multi-agent-workflow-v3-bootstrap.tar.gz bootstrap_package/ scripts/ prompts/ hooks/ templates/ *.md requirements.txt
```

Share `multi-agent-workflow-v3-bootstrap.tar.gz`. Users can:
```bash
tar -xzf multi-agent-workflow-v3-bootstrap.tar.gz
cd bootstrap_package
bash install_bootstrap.sh
```

### Option 2: Git Repository

```bash
# Push to GitHub/GitLab
git remote add origin <your-repo-url>
git push -u origin main
```

Users can:
```bash
git clone <your-repo-url>
cd <repo>/workflow_v3/bootstrap_package
bash install_bootstrap.sh
```

## Updating

To update the bootstrap skill on a computer:

```bash
# Get the latest version
cd /path/to/workflow_v3/bootstrap_package

# Reinstall (will overwrite)
bash install_bootstrap.sh
```

All projects using the workflow will continue working. New projects bootstrapped after the update will get the new version.

## Uninstalling

To remove the global skill:

```bash
rm ~/.claude/skills/bootstrap-workflow.md
rm -rf ~/.claude/workflow_assets
```

This doesn't affect projects that already have the workflow installed.

## Support

After bootstrapping a project:
- Read `.workflow/README.md` for complete documentation
- Check `.workflow/QUICK_START.md` for guided tutorial
- Review prompts in `.workflow/prompts/` to understand roles
- Run monitor: `python3 .workflow/scripts/evolution/self_healing_monitor.py`

## Version

**v3.0.0** - Initial release with bootstrap packaging
