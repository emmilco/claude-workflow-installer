#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"

echo "==================================="
echo "Multi-Agent Workflow Installer v3"
echo "==================================="
echo ""

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist"
    exit 1
fi

cd "$TARGET_DIR"

echo "Installing to: $(pwd)"
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p .workflow/{scripts,prompts,hooks,templates,monitoring,evidence,task_cards}
mkdir -p .workflow/scripts/{core,worktree,ci,evolution}
mkdir -p .workflow/prompts/archive
mkdir -p worktrees

# Copy scripts
echo "Copying scripts..."
cp -r "$SCRIPT_DIR/scripts/"* .workflow/scripts/

# Copy prompts
echo "Copying role prompts..."
cp -r "$SCRIPT_DIR/prompts/"* .workflow/prompts/

# Copy hooks
echo "Copying hooks..."
cp -r "$SCRIPT_DIR/hooks/"* .workflow/hooks/

# Copy templates
echo "Copying templates..."
cp -r "$SCRIPT_DIR/templates/"* .workflow/templates/

# Make scripts executable
echo "Setting permissions..."
chmod +x .workflow/scripts/**/*.sh
chmod +x .workflow/scripts/**/*.py
chmod +x .workflow/hooks/*.sh

# Initialize state files
echo "Initializing state files..."

if [ ! -f "TASKS.jsonl" ]; then
    touch TASKS.jsonl
    echo "Created TASKS.jsonl"
fi

if [ ! -f "IN_PROGRESS.md" ]; then
    cat > IN_PROGRESS.md <<'EOF'
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
EOF
    echo "Created IN_PROGRESS.md"
fi

if [ ! -f "DECISIONS.md" ]; then
    cat > DECISIONS.md <<'EOF'
# Decision Log

All architectural and implementation decisions are recorded here with evidence and rationale.

---
EOF
    echo "Created DECISIONS.md"
fi

# Install Claude Code skill
echo "Installing Claude Code skill..."
mkdir -p .claude/skills
cp "$SCRIPT_DIR/SKILL.md" .claude/skills/multi-agent-workflow.md

# Configure hooks (optional - ask user)
read -p "Configure Claude Code hooks for workflow enforcement? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ ! -f ".claude/settings.json" ]; then
        cat > .claude/settings.json <<'EOF'
{
  "hooks": {
    "PreToolUse": ".workflow/hooks/pre_tool_use.sh",
    "Stop": ".workflow/hooks/stop_gate.sh"
  }
}
EOF
        echo "Created .claude/settings.json with hooks"
    else
        echo "Warning: .claude/settings.json already exists. Please manually add hooks:"
        echo '  "PreToolUse": ".workflow/hooks/pre_tool_use.sh"'
        echo '  "Stop": ".workflow/hooks/stop_gate.sh"'
    fi
fi

# Install Python dependencies
echo ""
read -p "Install Python dependencies? (requires pip) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v pip3 &> /dev/null; then
        pip3 install -r "$SCRIPT_DIR/requirements.txt" || echo "Warning: Some dependencies failed to install"
    else
        echo "Warning: pip3 not found. Please manually install dependencies from requirements.txt"
    fi
fi

echo ""
echo "==================================="
echo "Installation Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Review .workflow/prompts/ to customize role behaviors"
echo "2. Create your first task: python3 .workflow/scripts/core/task_manager.py create-task --title 'Your task'"
echo "3. Spawn an agent: bash .workflow/scripts/worktree/spawn_agent.sh architect"
echo "4. Read docs: cat .workflow/docs/USAGE.md"
echo ""
echo "To start the self-healing monitor:"
echo "  python3 .workflow/scripts/evolution/self_healing_monitor.py --daemon"
echo ""
