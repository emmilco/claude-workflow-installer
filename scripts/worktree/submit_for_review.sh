#!/usr/bin/env bash
# Submit task for review
# Usage: submit_for_review.sh <task_id>

set -e

TASK_ID=$1

if [ -z "$TASK_ID" ]; then
    echo "Usage: submit_for_review.sh <task_id>"
    exit 1
fi

echo "==================================="
echo "Submitting Task for Review"
echo "Task ID: $TASK_ID"
echo "==================================="
echo ""

# Get task info
TASK_JSON=$(python3 .workflow/scripts/core/task_manager.py get-next-task --role any 2>/dev/null | jq -r ". | select(.task_id == \"$TASK_ID\")" || true)

if [ -z "$TASK_JSON" ]; then
    # Try to get from all tasks
    TASK_JSON=$(python3 .workflow/scripts/core/task_manager.py list-tasks | jq -r ".[] | select(.task_id == \"$TASK_ID\")")
fi

if [ -z "$TASK_JSON" ]; then
    echo "Error: Task $TASK_ID not found"
    exit 1
fi

WORKTREE=$(echo "$TASK_JSON" | jq -r '.worktree_path')
AGENT_ID=$(echo "$TASK_JSON" | jq -r '.claimed_by')

# Ensure we're in the worktree
if [ ! -f ".workflow/CURRENT_TASK.yaml" ]; then
    echo "Error: Must run from task worktree"
    echo "Expected to find .workflow/CURRENT_TASK.yaml"
    exit 1
fi

echo "Creating evidence package..."
echo ""

# Create evidence directory
EVIDENCE_DIR="../.workflow/evidence/$TASK_ID"
mkdir -p "$EVIDENCE_DIR"

# Capture git status
echo "Capturing changes..."
git status > "$EVIDENCE_DIR/git_status.txt"
git diff main > "$EVIDENCE_DIR/changes.diff"

# Run tests (if test command exists)
echo "Running tests..."
if [ -f "package.json" ] && grep -q '"test"' package.json; then
    npm test > "$EVIDENCE_DIR/test_output.txt" 2>&1 || echo "Tests failed - review may reject"
elif [ -f "pytest.ini" ] || [ -d "tests" ]; then
    pytest --tb=short > "$EVIDENCE_DIR/test_output.txt" 2>&1 || echo "Tests failed - review may reject"
else
    echo "No test suite detected - skipping tests"
    echo "No tests run" > "$EVIDENCE_DIR/test_output.txt"
fi

# Create implementer claim
CLAIM_FILE="$EVIDENCE_DIR/implementer_claim.json"
cat > "$CLAIM_FILE" <<EOF
{
  "claim_id": "${TASK_ID}-claim-$(date +%s)",
  "task_id": "$TASK_ID",
  "agent_id": "$AGENT_ID",
  "role": "implementer",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": "Implementation completed - ready for review",
  "files_modified": $(git diff --name-only main | jq -R -s -c 'split("\n") | map(select(length > 0))'),
  "test_results": "See test_output.txt",
  "evidence_files": [
    "git_status.txt",
    "changes.diff",
    "test_output.txt"
  ],
  "confidence": 0.85
}
EOF

# Compute SHA256 of evidence
EVIDENCE_HASH=$(find "$EVIDENCE_DIR" -type f -exec sha256sum {} \; | sort | sha256sum | awk '{print $1}')
echo "  \"evidence_sha256\": \"$EVIDENCE_HASH\"" >> "$CLAIM_FILE.tmp"
cat "$CLAIM_FILE" | jq ". + {evidence_sha256: \"$EVIDENCE_HASH\"}" > "$CLAIM_FILE.tmp"
mv "$CLAIM_FILE.tmp" "$CLAIM_FILE"

echo "✓ Evidence created in $EVIDENCE_DIR"
echo "✓ Evidence hash: $EVIDENCE_HASH"
echo ""

# Commit changes in worktree
echo "Committing changes in worktree..."
git add .
git commit -m "Complete task $TASK_ID

$(cat .workflow/CURRENT_TASK.yaml | grep 'title:' | cut -d: -f2-)

Evidence: $EVIDENCE_DIR
Agent: $AGENT_ID
" || echo "No changes to commit or already committed"

echo ""
echo "==================================="
echo "Ready for Review"
echo "==================================="
echo ""
echo "Task $TASK_ID is ready for review."
echo ""
echo "Next step - spawn a Reviewer agent:"
echo "  bash .workflow/scripts/worktree/spawn_reviewer.sh $TASK_ID"
echo ""
echo "Or manually review and complete:"
echo "  python3 .workflow/scripts/core/task_manager.py complete-task \\"
echo "    --task-id $TASK_ID \\"
echo "    --verdict approved \\"
echo "    --notes 'Review notes here'"
echo ""
