#!/usr/bin/env bash
# Complete a review and merge or reject
# Usage: complete_review.sh <task_id> <approved|rejected> [notes]

set -e

TASK_ID=$1
VERDICT=$2
NOTES="${3:-Review completed}"

if [ -z "$TASK_ID" ] || [ -z "$VERDICT" ]; then
    echo "Usage: complete_review.sh <task_id> <approved|rejected> [notes]"
    exit 1
fi

if [ "$VERDICT" != "approved" ] && [ "$VERDICT" != "rejected" ]; then
    echo "Error: Verdict must be 'approved' or 'rejected'"
    exit 1
fi

echo "==================================="
echo "Completing Review"
echo "Task ID: $TASK_ID"
echo "Verdict: $VERDICT"
echo "==================================="
echo ""

# Complete the task via task manager
python3 .workflow/scripts/core/task_manager.py complete-task \
    --task-id "$TASK_ID" \
    --verdict "$VERDICT" \
    --notes "$NOTES"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Review completed successfully"
    echo ""

    if [ "$VERDICT" == "approved" ]; then
        echo "Task has been merged to main"
        echo "Worktree has been cleaned up"
    else
        echo "Task has been rejected and returned to available tasks"
        echo "Worktree has been cleaned up"
    fi
else
    echo "Error completing review"
    exit 1
fi
