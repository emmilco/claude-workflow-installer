#!/usr/bin/env bash
# Spawn an agent for a specific role
# Usage: spawn_agent.sh <role>

set -e

ROLE=$1

if [ -z "$ROLE" ]; then
    echo "Usage: spawn_agent.sh <role>"
    echo "Available roles: architect, implementer, reviewer, integrator, tester, monitor"
    exit 1
fi

# Generate agent ID
AGENT_ID="${ROLE}-$(date +%s)-$$"

echo "==================================="
echo "Spawning $ROLE Agent"
echo "Agent ID: $AGENT_ID"
echo "==================================="
echo ""

# Get next available task
echo "Finding next available task for role: $ROLE..."
TASK_JSON=$(python3 .workflow/scripts/core/task_manager.py get-next-task --role "$ROLE")

if echo "$TASK_JSON" | grep -q '"error"'; then
    echo "No tasks available for role $ROLE"
    echo "You can create a task with:"
    echo "  python3 .workflow/scripts/core/task_manager.py create-task --title 'Task title' --description 'Description' --role '$ROLE'"
    exit 0
fi

TASK_ID=$(echo "$TASK_JSON" | jq -r '.task_id')
TASK_TITLE=$(echo "$TASK_JSON" | jq -r '.title')
TASK_DESC=$(echo "$TASK_JSON" | jq -r '.description')

echo "Selected task: $TASK_ID - $TASK_TITLE"
echo ""

# Claim the task
echo "Claiming task..."
CLAIM_RESULT=$(python3 .workflow/scripts/core/task_manager.py claim-task \
    --task-id "$TASK_ID" \
    --agent-id "$AGENT_ID" \
    --role "$ROLE" 2>&1)

if [ $? -ne 0 ]; then
    echo "Failed to claim task:"
    echo "$CLAIM_RESULT"
    exit 1
fi

WORKTREE=$(echo "$CLAIM_RESULT" | jq -r '.worktree')

echo "✓ Task claimed"
echo "✓ Worktree created: $WORKTREE"
echo ""

# Load role prompt
PROMPT_FILE=".workflow/prompts/${ROLE}.md"
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Warning: Role prompt not found: $PROMPT_FILE"
    echo "Using generic prompt"
    PROMPT="You are a $ROLE agent. Complete the assigned task."
else
    PROMPT=$(cat "$PROMPT_FILE")
fi

# Create task card in worktree
TASK_CARD_FILE="$WORKTREE/.workflow/CURRENT_TASK.yaml"
mkdir -p "$WORKTREE/.workflow"

cat > "$TASK_CARD_FILE" <<EOF
task_id: $TASK_ID
title: $TASK_TITLE
description: |
  $TASK_DESC

agent_id: $AGENT_ID
role: $ROLE
claimed_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

acceptance_criteria:
  - unit_tests pass
  - integration_smoke pass
  - reviewer approval

instructions: |
  Work in this worktree ($(basename $WORKTREE)) to implement the task.

  When done:
  1. Run tests and capture evidence
  2. Create a claim with evidence file
  3. Signal ready for review

  Do NOT merge to main yourself - the Reviewer will handle that.
EOF

echo "==================================="
echo "Agent Ready"
echo "==================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Change to worktree:"
echo "   cd $WORKTREE"
echo ""
echo "2. View your task:"
echo "   cat .workflow/CURRENT_TASK.yaml"
echo ""
echo "3. Start working on the task"
echo ""
echo "4. When complete, create evidence and signal for review:"
echo "   bash .workflow/scripts/worktree/submit_for_review.sh $TASK_ID"
echo ""
echo "Role Prompt:"
echo "----------------------------------------"
echo "$PROMPT" | head -20
echo "..."
echo ""
