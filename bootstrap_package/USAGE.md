# Bootstrap Workflow - Detailed Usage Guide

## One-Time Setup (Per Computer)

Install the bootstrap skill globally once:

```bash
cd workflow_v3/bootstrap_package
bash install_bootstrap.sh
```

**What this does:**
- Installs `bootstrap-workflow` skill to `~/.claude/skills/`
- Copies all workflow files to `~/.claude/workflow_assets/`
- Makes the skill available across all projects

**You only do this once per computer.**

## Using the Skill (Per Project)

### Starting Fresh in a New Project

```bash
# 1. Create or navigate to your project
mkdir my-new-project
cd my-new-project

# 2. Initialize git if not already
git init
git commit --allow-empty -m "Initial commit"

# 3. Start Claude Code
claude-code

# 4. Say to Claude (any of these phrases work):
"bootstrap the workflow"
"install the multi-agent workflow"
"setup workflow"
"install workflow v3"
```

Claude will:
1. ✅ Check prerequisites (git, python, jq)
2. ✅ Create `.workflow/` structure
3. ✅ Install all scripts and prompts
4. ✅ Initialize state files
5. ✅ Configure hooks (asks permission)
6. ✅ Give you next steps

### After Bootstrap Completes

Immediately usable commands:

```bash
# Create a task
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Add user authentication" \
  --description "Implement JWT-based auth" \
  --role "implementer" \
  --priority "high"

# Spawn an agent to work on it
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# The agent claims a task and creates a worktree
# Output shows: cd worktrees/TASK-XXXXXXXX-XXXX
```

## Workflow After Bootstrap

### 1. Agent Works in Worktree

```bash
cd worktrees/TASK-XXXXXXXX-XXXX

# View task
cat .workflow/CURRENT_TASK.yaml

# Do your work
# - Write code
# - Add tests
# - Commit changes

# Submit for review when done
bash .workflow/scripts/worktree/submit_for_review.sh TASK-XXXXXXXX-XXXX
```

### 2. Reviewer Evaluates

```bash
# Back to main repo
cd ../../

# Spawn reviewer
bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-XXXXXXXX-XXXX

# Reviewer examines:
# - Code in worktree
# - Evidence in .workflow/evidence/TASK-XXXXXXXX-XXXX/
# - Test results, diffs, git status

# Make decision
bash .workflow/scripts/worktree/complete_review.sh TASK-XXXXXXXX-XXXX approved "Great work!"
```

### 3. System Merges and Cleans Up

Automatically:
- ✅ Merges worktree to main (no-fast-forward)
- ✅ Removes worktree
- ✅ Updates task status to completed
- ✅ Preserves evidence

## Common Scenarios

### Scenario: Multiple Agents Working in Parallel

```bash
# Terminal 1
bash .workflow/scripts/worktree/spawn_agent.sh implementer
# Agent 1 gets TASK-001, works in worktrees/TASK-001

# Terminal 2
bash .workflow/scripts/worktree/spawn_agent.sh implementer
# Agent 2 gets TASK-002, works in worktrees/TASK-002

# Terminal 3
bash .workflow/scripts/worktree/spawn_agent.sh reviewer
# Agent 3 reviews completed tasks

# No conflicts! Each worktree is isolated.
```

### Scenario: Monitoring Health

```bash
# One-time check
python3 .workflow/scripts/evolution/self_healing_monitor.py

# View dashboard
cat .workflow/monitoring/DASHBOARD.md

# Continuous monitoring (daemon)
python3 .workflow/scripts/evolution/self_healing_monitor.py --daemon --interval 3600
```

### Scenario: Improving Prompts

```bash
# After 10-20 completed tasks, analyze outcomes
python3 .workflow/scripts/evolution/evolve_prompts.py analyze

# See specific suggestions for a role
python3 .workflow/scripts/evolution/evolve_prompts.py propose --role implementer

# Review the proposal and manually update prompts
# Or auto-apply basic improvements (experimental)
python3 .workflow/scripts/evolution/evolve_prompts.py apply --role implementer --auto
```

### Scenario: Task Stuck/Stale

```bash
# Manual check
python3 .workflow/scripts/core/task_manager.py detect-stale

# Force release if needed
python3 .workflow/scripts/core/task_manager.py force-release \
  --task-id TASK-001 \
  --reason "Agent crashed"

# Or let monitor auto-cleanup
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Bootstrap in Existing Projects

If your project already has code:

```bash
cd my-existing-project

# Make sure you have clean git state
git status  # Should show "working tree clean"

# If not clean, commit first
git add .
git commit -m "State before workflow installation"

# Now bootstrap
claude-code
# Say: "bootstrap the workflow"
```

The workflow installs alongside your existing code. It doesn't modify your files.

## Updating Existing Workflow Installation

To update a project that already has the workflow:

```bash
cd my-project-with-workflow

# Backup state (tasks, evidence)
cp TASKS.jsonl TASKS.jsonl.backup
cp -r .workflow/evidence .workflow/evidence.backup

# Remove old scripts/prompts
rm -rf .workflow/scripts .workflow/prompts .workflow/hooks .workflow/templates

# Re-bootstrap (Update mode)
claude-code
# Say: "bootstrap the workflow"
# Choose "update" when prompted

# Your tasks and evidence are preserved
```

## Troubleshooting

### Issue: "bootstrap the workflow" doesn't activate the skill

**Cause:** Skill not installed globally or Claude not recognizing it

**Solution:**
```bash
# Verify skill installed
ls ~/.claude/skills/bootstrap-workflow.md

# If not found, reinstall
cd workflow_v3/bootstrap_package
bash install_bootstrap.sh

# Restart Claude Code
```

### Issue: Prerequisites check fails

**Cause:** Missing git/python/jq

**Solution:**
```bash
# macOS
brew install git python3 jq

# Ubuntu/Debian
sudo apt-get install git python3 jq

# Verify versions
git --version      # Need 2.25+
python3 --version  # Need 3.7+
jq --version       # Any version
```

### Issue: "Not a git repository"

**Cause:** Project not initialized with git

**Solution:**
```bash
git init
git add .
git commit -m "Initial commit"
# Now bootstrap
```

### Issue: Permission denied on scripts

**Cause:** Scripts not executable after bootstrap

**Solution:**
```bash
chmod +x .workflow/scripts/**/*.sh
chmod +x .workflow/scripts/**/*.py
chmod +x .workflow/hooks/*.sh
```

## Advanced: Customizing Before Bootstrap

If you want to customize the workflow before bootstrapping:

```bash
# 1. Edit the global assets
cd ~/.claude/workflow_assets

# 2. Customize prompts
vim prompts/implementer.md

# 3. Modify scripts
vim scripts/core/task_manager.py

# 4. Bootstrap new projects
# They'll get your customizations
```

## Advanced: Multiple Versions

To maintain multiple workflow versions:

```bash
# Install v3 normally
cd workflow_v3/bootstrap_package
bash install_bootstrap.sh

# Rename for v3-specific name
mv ~/.claude/skills/bootstrap-workflow.md \
   ~/.claude/skills/bootstrap-workflow-v3.md

# Install v4 when available
cd workflow_v4/bootstrap_package
bash install_bootstrap.sh

# Now you have both:
# - "bootstrap the workflow v3" triggers v3
# - "bootstrap the workflow" triggers v4 (latest)
```

## Sharing With Team

### Option 1: Share the Package

```bash
# Create archive
cd workflow_v3
tar -czf multi-agent-workflow-bootstrap.tar.gz bootstrap_package/ scripts/ prompts/ hooks/ templates/ *.md

# Share multi-agent-workflow-bootstrap.tar.gz
# Team members extract and run:
tar -xzf multi-agent-workflow-bootstrap.tar.gz
cd bootstrap_package
bash install_bootstrap.sh
```

### Option 2: Git Repository

```bash
# Push to company Git
git remote add origin git@github.com:company/workflow.git
git push -u origin main

# Team members clone and install:
git clone git@github.com:company/workflow.git
cd workflow/workflow_v3/bootstrap_package
bash install_bootstrap.sh
```

### Option 3: Shared Network Drive

```bash
# Copy to shared location
cp -r workflow_v3 /shared/engineering/tools/

# Team members install from shared drive:
bash /shared/engineering/tools/workflow_v3/bootstrap_package/install_bootstrap.sh
```

## Quick Reference

```bash
# Install globally (once per computer)
bash install_bootstrap.sh

# Bootstrap a project
claude-code
# Say: "bootstrap the workflow"

# Or manual bootstrap
bash ~/.claude/workflow_assets/bootstrap.sh .

# After bootstrap - create task
python3 .workflow/scripts/core/task_manager.py create-task --title "..." --description "..." --role "implementer"

# Spawn agent
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Submit for review
bash .workflow/scripts/worktree/submit_for_review.sh TASK-ID

# Complete review
bash .workflow/scripts/worktree/complete_review.sh TASK-ID approved "Notes"

# Monitor
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

That's everything you need to know!
