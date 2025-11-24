#!/usr/bin/env bash
# Automated project setup script
# Run this in a project directory to set up the workflow structure

set -e

echo "=========================================="
echo "Multi-Agent Workflow - Project Setup v3.1"
echo "=========================================="
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: Not in a git repository root"
    echo "Please run this from your project's root directory"
    exit 1
fi

# Check if workflow already set up
if [ -d ".workflow" ] && [ -f "TASKS.jsonl" ]; then
    read -p "Workflow already exists. Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "Setting up workflow structure..."
echo ""

# Create directory structure
echo "Creating directories..."
mkdir -p .workflow/{scripts,prompts,hooks,templates,monitoring,evidence}
mkdir -p .workflow/scripts/{core,worktree,evolution}
mkdir -p .workflow/prompts/archive
mkdir -p worktrees

# Check if global installation exists
SKILL_DIR="$HOME/.claude/skills/multi-agent-workflow"
if [ ! -d "$SKILL_DIR" ]; then
    echo "ERROR: Global workflow files not found at $SKILL_DIR"
    echo "Please run install.sh first to install globally:"
    echo "  bash /path/to/workflow_installer/install.sh"
    exit 1
fi

# Copy files from global installation
echo "Copying workflow files from global installation..."
cp -r "$SKILL_DIR/scripts/"* .workflow/scripts/
cp -r "$SKILL_DIR/prompts/"* .workflow/prompts/
cp -r "$SKILL_DIR/hooks/"* .workflow/hooks/
cp -r "$SKILL_DIR/templates/"* .workflow/templates/

# Make scripts executable
echo "Setting permissions..."
find .workflow/scripts -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
find .workflow/hooks -type f -name "*.sh" -exec chmod +x {} +

# Initialize state files
echo "Initializing state files..."

# Create empty TASKS.jsonl if it doesn't exist
if [ ! -f "TASKS.jsonl" ]; then
    touch TASKS.jsonl
    echo "✓ Created TASKS.jsonl"
else
    echo "✓ TASKS.jsonl already exists (keeping existing content)"
fi

# Create IN_PROGRESS.md
cat > IN_PROGRESS.md <<'EOF'
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
EOF
echo "✓ Created IN_PROGRESS.md"

# Create DECISIONS.md
if [ ! -f "DECISIONS.md" ]; then
    cat > DECISIONS.md <<'EOF'
# Architectural Decision Log

This file records important architectural and implementation decisions made during the project.

## Decision Template

**Decision:** [Brief title]
**Date:** YYYY-MM-DD
**Status:** [Proposed | Accepted | Rejected | Superseded]
**Context:** [What is the issue we're trying to solve?]
**Options Considered:**
1. [Option 1]
2. [Option 2]
**Decision:** [What we decided]
**Rationale:** [Why we decided this]
**Consequences:** [What are the trade-offs?]

---

EOF
    echo "✓ Created DECISIONS.md"
else
    echo "✓ DECISIONS.md already exists (keeping existing content)"
fi

# Add to .gitignore
echo "Updating .gitignore..."
if [ -f ".gitignore" ]; then
    # Check if workflow entries already exist
    if ! grep -q "# Multi-Agent Workflow" .gitignore; then
        cat >> .gitignore <<'EOF'

# Multi-Agent Workflow - State Files
TASKS.jsonl
IN_PROGRESS.md
.tasks.lock
worktrees/
.workflow/evidence/
.workflow/monitoring/
EOF
        echo "✓ Added workflow entries to .gitignore"
    else
        echo "✓ .gitignore already has workflow entries"
    fi
else
    cat > .gitignore <<'EOF'
# Multi-Agent Workflow - State Files
TASKS.jsonl
IN_PROGRESS.md
.tasks.lock
worktrees/
.workflow/evidence/
.workflow/monitoring/

# Python
__pycache__/
*.pyc
*.pyo

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
EOF
    echo "✓ Created .gitignore"
fi

# Create Claude Code skill symlink or note
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
if [ -d "$CLAUDE_SKILLS_DIR" ]; then
    if [ ! -f ".claude/skills/multi-agent-workflow.md" ]; then
        mkdir -p .claude/skills
        ln -s "$CLAUDE_SKILLS_DIR/multi-agent-workflow.md" .claude/skills/multi-agent-workflow.md 2>/dev/null || \
            cp "$CLAUDE_SKILLS_DIR/multi-agent-workflow.md" .claude/skills/multi-agent-workflow.md
        echo "✓ Linked Claude Code skill"
    fi
fi

# Git commit workflow setup
echo ""
echo "Committing workflow setup..."
git add .workflow/ .gitignore IN_PROGRESS.md
if [ -f "DECISIONS.md" ] && [ "$(git diff --cached DECISIONS.md)" != "" ]; then
    git add DECISIONS.md
fi

if git diff --cached --quiet; then
    echo "No changes to commit (workflow already set up)"
else
    git commit -m "Set up multi-agent workflow structure

- Added .workflow/ directory with scripts, prompts, hooks, templates
- Initialized IN_PROGRESS.md and DECISIONS.md
- Updated .gitignore to exclude runtime state files
- Ready for multi-agent development

🤖 Generated with Multi-Agent Workflow Installer v3"
    echo "✓ Committed workflow setup"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Your project is now set up for multi-agent workflow."
echo ""
echo "Next steps:"
echo ""
echo "1. Create your first task:"
echo "   python3 .workflow/scripts/core/task_manager.py create-task \\"
echo "     --title 'Your task title' \\"
echo "     --description 'Task description' \\"
echo "     --role 'implementer'"
echo ""
echo "2. Spawn an agent:"
echo "   bash .workflow/scripts/worktree/spawn_agent.sh implementer"
echo ""
echo "3. Read the documentation:"
echo "   - README.md - Complete usage guide"
echo "   - QUICK_START.md - Fast getting started"
echo "   - ARCHITECTURE.md - Technical details"
echo "   - TROUBLESHOOTING.md - Common issues"
echo ""
echo "4. Monitor system health:"
echo "   python3 .workflow/scripts/evolution/self_healing_monitor.py"
echo ""
echo "Happy multi-agent development!"
echo ""
