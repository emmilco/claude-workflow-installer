#!/usr/bin/env bash
# Spawn a reviewer agent for a specific task
# Usage: spawn_reviewer.sh <task_id>

set -e

TASK_ID=$1

if [ -z "$TASK_ID" ]; then
    echo "Usage: spawn_reviewer.sh <task_id>"
    exit 1
fi

AGENT_ID="reviewer-$(date +%s)-$$"

echo "==================================="
echo "Spawning Reviewer Agent"
echo "Agent ID: $AGENT_ID"
echo "Task ID: $TASK_ID"
echo "==================================="
echo ""

# Get task info
TASKS=$(python3 .workflow/scripts/core/task_manager.py list-tasks)
TASK=$(echo "$TASKS" | jq -r ".[] | select(.task_id == \"$TASK_ID\")")

if [ -z "$TASK" ]; then
    echo "Error: Task $TASK_ID not found"
    exit 1
fi

STATUS=$(echo "$TASK" | jq -r '.status')
if [ "$STATUS" != "claimed" ]; then
    echo "Error: Task must be in 'claimed' status for review (current: $STATUS)"
    exit 1
fi

WORKTREE=$(echo "$TASK" | jq -r '.worktree_path')
EVIDENCE_DIR=".workflow/evidence/$TASK_ID"

if [ ! -d "$EVIDENCE_DIR" ]; then
    echo "Error: Evidence not found for task $TASK_ID"
    echo "Implementer must submit for review first"
    exit 1
fi

echo "Reviewing task: $(echo "$TASK" | jq -r '.title')"
echo "Evidence location: $EVIDENCE_DIR"
echo ""

# Load reviewer prompt
PROMPT_FILE=".workflow/prompts/reviewer.md"
if [ -f "$PROMPT_FILE" ]; then
    PROMPT=$(cat "$PROMPT_FILE")
else
    PROMPT="You are a Reviewer. Evaluate the implementation for correctness, style, and adherence to requirements."
fi

# Create review workspace
REVIEW_DIR=".workflow/evidence/$TASK_ID/review"
mkdir -p "$REVIEW_DIR"

# Package review context
cat > "$REVIEW_DIR/review_context.md" <<EOF
# Review Context for $TASK_ID

## Task Details
$(echo "$TASK" | jq -r '.')

## Evidence Files
- Implementer Claim: $EVIDENCE_DIR/implementer_claim.json
- Changes: $EVIDENCE_DIR/changes.diff
- Test Output: $EVIDENCE_DIR/test_output.txt
- Git Status: $EVIDENCE_DIR/git_status.txt

## Review Checklist
- [ ] Code correctness
- [ ] Test coverage
- [ ] Style adherence
- [ ] Security concerns
- [ ] Performance implications
- [ ] Documentation

## Reviewer Role Prompt
$PROMPT

---

## Instructions for Reviewer
1. Examine the evidence files above
2. Review the code changes in the worktree: $WORKTREE
3. Create a review report at: $REVIEW_DIR/review_report.json
4. Make your verdict: approved or rejected

Use the review template at: .workflow/templates/review_report.template.json

When done, complete the review with:
  bash .workflow/scripts/worktree/complete_review.sh $TASK_ID <approved|rejected>
EOF

echo "==================================="
echo "Review Ready"
echo "==================================="
echo ""
echo "Review context: $REVIEW_DIR/review_context.md"
echo ""
echo "Next steps:"
echo "1. Read review context:"
echo "   cat $REVIEW_DIR/review_context.md"
echo ""
echo "2. Examine evidence:"
echo "   cat $EVIDENCE_DIR/implementer_claim.json"
echo "   cat $EVIDENCE_DIR/changes.diff"
echo "   cat $EVIDENCE_DIR/test_output.txt"
echo ""
echo "3. Review code in worktree:"
echo "   cd $WORKTREE"
echo ""
echo "4. Complete review:"
echo "   bash .workflow/scripts/worktree/complete_review.sh $TASK_ID approved"
echo "   # or"
echo "   bash .workflow/scripts/worktree/complete_review.sh $TASK_ID rejected"
echo ""
