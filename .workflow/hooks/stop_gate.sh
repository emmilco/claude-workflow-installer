#!/usr/bin/env bash
# Stop hook - runs after agent completes a response
# Lightweight validation only - not full test suite

# Only run in worktrees
if [[ "$PWD" != *"/worktrees/"* ]]; then
    exit 0
fi

# Check if we're in a task context
if [ ! -f ".workflow/CURRENT_TASK.yaml" ]; then
    exit 0
fi

# Quick validations (must be fast, < 10 seconds)

# 1. Check for obvious syntax errors if Python/JS project
if [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
    # Quick Python syntax check
    if command -v python3 &> /dev/null; then
        find . -name "*.py" -not -path "./.venv/*" -not -path "./venv/*" -exec python3 -m py_compile {} \; 2>/dev/null || {
            echo "⚠️  Warning: Python syntax errors detected"
        }
    fi
fi

if [ -f "package.json" ]; then
    # Quick JS syntax check
    if command -v node &> /dev/null; then
        # Just check if package.json is valid
        node -e "require('./package.json')" 2>/dev/null || {
            echo "⚠️  Warning: package.json syntax error"
        }
    fi
fi

# 2. Check for accidentally committed secrets (basic check)
if git diff --cached --name-only | grep -E '\.(env|pem|key|p12)$'; then
    echo "⚠️  Warning: Potential secret files staged (.env, .pem, .key files)"
fi

# 3. Reminder about evidence
if ! [ -d "../.workflow/evidence/$(basename $PWD)" ]; then
    echo "ℹ️  Reminder: Create evidence before submitting for review"
    echo "  bash .workflow/scripts/worktree/submit_for_review.sh $(basename $PWD)"
fi

# Always allow - this is informational only
exit 0
