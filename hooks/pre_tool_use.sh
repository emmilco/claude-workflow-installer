#!/usr/bin/env bash
# PreToolUse hook - validates before tool execution
# Can block dangerous operations

TOOL_NAME="$1"
TOOL_INPUT="$2"

# Only enforce in worktrees
if [[ "$PWD" != *"/worktrees/"* ]]; then
    exit 0  # Allow - not in workflow context
fi

# Validate we're in a claimed task
if [ ! -f ".workflow/CURRENT_TASK.yaml" ]; then
    echo "Warning: Not in a task worktree - some validations skipped"
    exit 0
fi

# Prevent direct merge to main
if [ "$TOOL_NAME" == "Bash" ] && echo "$TOOL_INPUT" | grep -q "git merge.*main"; then
    echo "BLOCKED: Cannot merge to main from worktree"
    echo "Use the review workflow instead"
    exit 2  # Block
fi

# Prevent force push
if [ "$TOOL_NAME" == "Bash" ] && echo "$TOOL_INPUT" | grep -q "git push.*--force"; then
    echo "BLOCKED: Force push not allowed"
    exit 2  # Block
fi

# Prevent worktree removal while inside it
if [ "$TOOL_NAME" == "Bash" ] && echo "$TOOL_INPUT" | grep -q "git worktree remove"; then
    echo "BLOCKED: Cannot remove worktree from inside it"
    echo "Use complete_review.sh instead"
    exit 2  # Block
fi

# Allow all other operations
exit 0
