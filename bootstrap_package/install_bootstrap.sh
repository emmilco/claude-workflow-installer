#!/usr/bin/env bash
# Install the bootstrap-workflow skill globally for Claude Code
# This makes the skill available across all projects

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$HOME/.claude/skills"

echo "================================================"
echo "Bootstrap Workflow Skill - Global Installation"
echo "================================================"
echo ""

# Create global skills directory if it doesn't exist
mkdir -p "$SKILL_DIR"

# Check if skill already installed
if [ -f "$SKILL_DIR/bootstrap-workflow.md" ]; then
    echo "⚠️  bootstrap-workflow skill already installed globally"
    read -p "Overwrite with new version? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
fi

# Copy the skill file
echo "Installing bootstrap-workflow skill..."
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/bootstrap-workflow.md"

# Copy the entire workflow_v3 directory to a known location
WORKFLOW_ASSETS_DIR="$HOME/.claude/workflow_assets"
echo "Installing workflow assets..."
mkdir -p "$WORKFLOW_ASSETS_DIR"

# Copy all workflow files
cp -r "$SCRIPT_DIR/../scripts" "$WORKFLOW_ASSETS_DIR/"
cp -r "$SCRIPT_DIR/../prompts" "$WORKFLOW_ASSETS_DIR/"
cp -r "$SCRIPT_DIR/../hooks" "$WORKFLOW_ASSETS_DIR/"
cp -r "$SCRIPT_DIR/../templates" "$WORKFLOW_ASSETS_DIR/"
cp "$SCRIPT_DIR/../README.md" "$WORKFLOW_ASSETS_DIR/"
cp "$SCRIPT_DIR/../QUICK_START.md" "$WORKFLOW_ASSETS_DIR/"
cp "$SCRIPT_DIR/../requirements.txt" "$WORKFLOW_ASSETS_DIR/"
cp "$SCRIPT_DIR/../SKILL.md" "$WORKFLOW_ASSETS_DIR/multi-agent-workflow.md"

# Make scripts executable
chmod +x "$WORKFLOW_ASSETS_DIR/scripts"/**/*.sh
chmod +x "$WORKFLOW_ASSETS_DIR/scripts"/**/*.py
chmod +x "$WORKFLOW_ASSETS_DIR/hooks"/*.sh

# Create bootstrap script that Claude can call
cat > "$WORKFLOW_ASSETS_DIR/bootstrap.sh" <<'BOOTSTRAP_EOF'
#!/usr/bin/env bash
# Bootstrap script called by Claude Code to install workflow in a project

set -e

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

echo "==================================="
echo "Installing Multi-Agent Workflow v3"
echo "==================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Git repository
if ! git status &>/dev/null; then
    echo "❌ Error: Not a git repository"
    echo "Run: git init && git add . && git commit -m 'Initial commit'"
    exit 1
fi

# Git version
GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
GIT_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
GIT_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)
if [ "$GIT_MAJOR" -lt 2 ] || ([ "$GIT_MAJOR" -eq 2 ] && [ "$GIT_MINOR" -lt 25 ]); then
    echo "❌ Error: Git 2.25+ required (found $GIT_VERSION)"
    exit 1
fi

# Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 not found"
    echo "Install: brew install python3 (macOS) or apt-get install python3 (Linux)"
    exit 1
fi

# jq
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq not found"
    echo "Install: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

echo "✓ Git $(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
echo "✓ Python $(python3 --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
echo "✓ jq $(jq --version)"
echo ""

# Check for existing installation
if [ -d ".workflow" ]; then
    echo "⚠️  Existing .workflow directory found"
    read -p "Choose: [u]pdate, [c]lean install, [a]bort? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Aa]$ ]]; then
        echo "Installation cancelled"
        exit 0
    elif [[ $REPLY =~ ^[Cc]$ ]]; then
        echo "Removing existing installation..."
        rm -rf .workflow
    fi
fi

# Create directory structure
echo "Creating directory structure..."
mkdir -p .workflow/{scripts,prompts,hooks,templates,monitoring,evidence,task_cards}
mkdir -p .workflow/scripts/{core,worktree,ci,evolution}
mkdir -p .workflow/prompts/archive
mkdir -p worktrees

# Copy files from assets
ASSETS_DIR="$HOME/.claude/workflow_assets"

echo "Installing scripts..."
cp -r "$ASSETS_DIR/scripts/"* .workflow/scripts/

echo "Installing prompts..."
cp -r "$ASSETS_DIR/prompts/"* .workflow/prompts/

echo "Installing hooks..."
cp -r "$ASSETS_DIR/hooks/"* .workflow/hooks/

echo "Installing templates..."
cp -r "$ASSETS_DIR/templates/"* .workflow/templates/

echo "Installing documentation..."
cp "$ASSETS_DIR/README.md" .workflow/
cp "$ASSETS_DIR/QUICK_START.md" .workflow/

# Make scripts executable
chmod +x .workflow/scripts/**/*.sh
chmod +x .workflow/scripts/**/*.py
chmod +x .workflow/hooks/*.sh

# Initialize state files
echo "Initializing state files..."

if [ ! -f "TASKS.jsonl" ]; then
    touch TASKS.jsonl
    echo "✓ Created TASKS.jsonl"
fi

if [ ! -f "IN_PROGRESS.md" ]; then
    cat > IN_PROGRESS.md <<'EOF'
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
EOF
    echo "✓ Created IN_PROGRESS.md"
fi

if [ ! -f "DECISIONS.md" ]; then
    cat > DECISIONS.md <<'EOF'
# Decision Log

All architectural and implementation decisions are recorded here with evidence and rationale.

---
EOF
    echo "✓ Created DECISIONS.md"
fi

# Install Claude Code skill locally
echo ""
echo "Installing multi-agent-workflow skill to project..."
mkdir -p .claude/skills
cp "$ASSETS_DIR/multi-agent-workflow.md" .claude/skills/

# Configure hooks (ask user)
echo ""
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
        echo "✓ Created .claude/settings.json with hooks"
    else
        echo "⚠️  .claude/settings.json already exists"
        echo "   Manually add hooks:"
        echo "   \"PreToolUse\": \".workflow/hooks/pre_tool_use.sh\""
        echo "   \"Stop\": \".workflow/hooks/stop_gate.sh\""
    fi
fi

echo ""
echo "==================================="
echo "✓ Installation Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Create your first task:"
echo "   python3 .workflow/scripts/core/task_manager.py create-task \\"
echo "     --title 'Your task' \\"
echo "     --description 'Description' \\"
echo "     --role 'implementer'"
echo ""
echo "2. Spawn an agent:"
echo "   bash .workflow/scripts/worktree/spawn_agent.sh implementer"
echo ""
echo "3. Read documentation:"
echo "   cat .workflow/README.md"
echo "   cat .workflow/QUICK_START.md"
echo ""
echo "4. Monitor health:"
echo "   python3 .workflow/scripts/evolution/self_healing_monitor.py"
echo ""
BOOTSTRAP_EOF

chmod +x "$WORKFLOW_ASSETS_DIR/bootstrap.sh"

echo ""
echo "✓ Skill installed to: $SKILL_DIR/bootstrap-workflow.md"
echo "✓ Assets installed to: $WORKFLOW_ASSETS_DIR"
echo ""
echo "================================================"
echo "Installation Complete!"
echo "================================================"
echo ""
echo "The bootstrap-workflow skill is now available globally."
echo ""
echo "To use it in any project:"
echo "1. cd /path/to/your/project"
echo "2. Start Claude Code"
echo "3. Say: 'bootstrap the workflow'"
echo ""
echo "Claude will install the complete workflow system into that project."
echo ""
echo "You can also run the bootstrap manually:"
echo "  bash $WORKFLOW_ASSETS_DIR/bootstrap.sh /path/to/project"
echo ""
