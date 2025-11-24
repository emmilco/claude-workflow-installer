#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/multi-agent-workflow"

echo "==================================="
echo "Multi-Agent Workflow Installer v3"
echo "==================================="
echo ""

# Check for required dependencies
echo "Checking dependencies..."

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required but not installed."
    echo ""
    echo "Please install jq:"
    echo "  macOS:   brew install jq"
    echo "  Ubuntu:  sudo apt-get install jq"
    echo "  Fedora:  sudo dnf install jq"
    echo ""
    exit 1
fi
echo "✓ jq found"

if ! command -v git &> /dev/null; then
    echo "ERROR: git is required but not installed."
    exit 1
fi

# Check git version (need 2.25+ for worktree support)
GIT_VERSION=$(git --version | awk '{print $3}')
GIT_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
GIT_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)

if [ "$GIT_MAJOR" -lt 2 ] || ([ "$GIT_MAJOR" -eq 2 ] && [ "$GIT_MINOR" -lt 25 ]); then
    echo "ERROR: Git 2.25+ required (found $GIT_VERSION)"
    echo "Please upgrade git for worktree support"
    exit 1
fi
echo "✓ git $GIT_VERSION"

if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 is required but not installed."
    exit 1
fi
echo "✓ python3 found"
echo ""

# Create skill directory structure
echo "Creating skill directory structure..."
mkdir -p "$SKILL_DIR"/{scripts,prompts,hooks,templates}
mkdir -p "$SKILL_DIR"/scripts/{core,worktree,ci,evolution}
mkdir -p "$SKILL_DIR"/prompts/archive

# Install Claude Code skill
echo "Installing Claude Code skill..."
cp "$SCRIPT_DIR/SKILL.md" ~/.claude/skills/multi-agent-workflow.md
echo "✓ Skill installed to ~/.claude/skills/multi-agent-workflow.md"
echo ""

# Copy reference files adjacent to skill
echo "Installing workflow files..."

# Copy scripts
cp -r "$SCRIPT_DIR/scripts/"* "$SKILL_DIR/scripts/"

# Copy prompts
cp -r "$SCRIPT_DIR/prompts/"* "$SKILL_DIR/prompts/"

# Copy hooks
cp -r "$SCRIPT_DIR/hooks/"* "$SKILL_DIR/hooks/"

# Copy templates
cp -r "$SCRIPT_DIR/templates/"* "$SKILL_DIR/templates/"

# Make scripts executable
echo "Setting permissions..."
find "$SKILL_DIR/scripts" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
find "$SKILL_DIR/hooks" -type f -name "*.sh" -exec chmod +x {} +

echo "✓ Workflow files installed to $SKILL_DIR"
echo ""

# Install Python dependencies
read -p "Install Python dependencies globally? (requires pip) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v pip3 &> /dev/null; then
        pip3 install -r "$SCRIPT_DIR/requirements.txt" || echo "Warning: Some dependencies failed to install"
        echo "✓ Python dependencies installed"
    else
        echo "Warning: pip3 not found. Please manually install dependencies from requirements.txt"
    fi
fi

echo ""
echo "==================================="
echo "Installation Complete!"
echo "==================================="
echo ""
echo "The multi-agent workflow skill is now globally available in Claude Code."
echo ""
echo "Installation location:"
echo "  Skill: ~/.claude/skills/multi-agent-workflow.md"
echo "  Files: $SKILL_DIR"
echo ""
echo "To use the workflow in a project, activate the skill in Claude Code"
echo "and it will set up the necessary structure in your project."
echo ""
