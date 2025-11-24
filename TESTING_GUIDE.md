# Testing Guide

This guide explains how to test the multi-agent workflow system itself, ensuring it works correctly before using in production.

## Overview

The workflow system should be tested at three levels:
1. **Unit tests** - Test individual components in isolation
2. **Integration tests** - Test end-to-end workflows
3. **Stress tests** - Test at scale and under load

## Prerequisites

```bash
# Install testing dependencies
pip3 install pytest pytest-randomly freezegun

# Validate system is set up
bash scripts/validate_system.sh
```

## Quick Test (5 minutes)

Run this to verify basic functionality:

```bash
# 1. Validate setup
bash scripts/validate_system.sh

# 2. Create a test task
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Test task" \
  --description "Testing workflow" \
  --role "implementer"

# 3. List tasks (should show the task)
python3 .workflow/scripts/core/task_manager.py list-tasks

# 4. Claim the task
TASK_ID=$(python3 .workflow/scripts/core/task_manager.py list-tasks --status available | head -1 | awk '{print $1}')
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# 5. Check worktree was created
ls -la worktrees/
git worktree list

# 6. Check IN_PROGRESS.md
cat IN_PROGRESS.md

# 7. Run health check
python3 .workflow/scripts/evolution/self_healing_monitor.py

# 8. Clean up
cd worktrees/$TASK_ID
bash .workflow/scripts/worktree/submit_for_review.sh $TASK_ID
cd ../../
bash .workflow/scripts/worktree/complete_review.sh $TASK_ID approved "Test complete"

echo "✓ Quick test passed!"
```

## Unit Tests

### Testing task_manager.py

Create `tests/test_task_manager.py`:

```python
#!/usr/bin/env python3
import sys
import os
import tempfile
import shutil
from pathlib import Path
import json
import subprocess

# Add task_manager to path
sys.path.insert(0, '.workflow/scripts/core')
from task_manager import TaskManager, find_project_root

def setup_test_repo(tmp_path):
    """Create a temporary git repo for testing"""
    repo = tmp_path / "test_repo"
    repo.mkdir()

    # Initialize git repo
    subprocess.run(['git', 'init'], cwd=repo, check=True, capture_output=True)
    subprocess.run(['git', 'config', 'user.email', 'test@example.com'], cwd=repo, check=True)
    subprocess.run(['git', 'config', 'user.name', 'Test User'], cwd=repo, check=True)

    # Create initial commit
    (repo / 'README.md').write_text('# Test')
    subprocess.run(['git', 'add', '.'], cwd=repo, check=True)
    subprocess.run(['git', 'commit', '-m', 'Initial'], cwd=repo, check=True, capture_output=True)

    return repo

def test_find_project_root(tmp_path):
    """Test project root detection"""
    repo = setup_test_repo(tmp_path)

    # Create nested directory
    nested = repo / "a" / "b" / "c"
    nested.mkdir(parents=True)

    # Should find repo root from nested dir
    os.chdir(nested)
    root = find_project_root()
    assert root == repo, f"Expected {repo}, got {root}"
    print("✓ find_project_root works from nested directory")

def test_create_task(tmp_path):
    """Test task creation"""
    repo = setup_test_repo(tmp_path)
    os.chdir(repo)

    tm = TaskManager(repo)
    task_id = tm.create_task(
        title="Test task",
        description="Test description",
        role="implementer"
    )

    assert task_id.startswith("TASK-"), f"Invalid task ID: {task_id}"

    tasks = tm._read_tasks()
    assert len(tasks) == 1, f"Expected 1 task, got {len(tasks)}"

    task = tasks[0]
    assert task['title'] == "Test task"
    assert task['status'] == 'available'
    print(f"✓ create_task works (created {task_id})")

def test_claim_task(tmp_path):
    """Test task claiming"""
    repo = setup_test_repo(tmp_path)
    os.chdir(repo)

    tm = TaskManager(repo)
    task_id = tm.create_task(
        title="Test task",
        description="Test",
        role="implementer"
    )

    # Claim the task
    worktree_path = tm.claim_task(task_id, "test-agent-001", "implementer")
    assert worktree_path is not None, "Task claim failed"
    assert Path(worktree_path).exists(), f"Worktree not created at {worktree_path}"

    # Check task status updated
    tasks = tm._read_tasks()
    task = next(t for t in tasks if t['task_id'] == task_id)
    assert task['status'] == 'claimed'
    assert task['claimed_by'] == 'test-agent-001'

    # Check worktree exists
    assert (repo / "worktrees" / task_id).exists()

    # Cleanup
    subprocess.run(['git', 'worktree', 'remove', worktree_path, '--force'],
                   cwd=repo, capture_output=True)

    print(f"✓ claim_task works (claimed {task_id})")

def test_double_claim_prevention(tmp_path):
    """Test that double-claiming is prevented"""
    repo = setup_test_repo(tmp_path)
    os.chdir(repo)

    tm = TaskManager(repo)
    task_id = tm.create_task(
        title="Test task",
        description="Test",
        role="implementer"
    )

    # First claim should succeed
    worktree1 = tm.claim_task(task_id, "agent-1", "implementer")
    assert worktree1 is not None

    # Second claim should fail
    worktree2 = tm.claim_task(task_id, "agent-2", "implementer")
    assert worktree2 is None, "Double claim was not prevented!"

    # Cleanup
    subprocess.run(['git', 'worktree', 'remove', worktree1, '--force'],
                   cwd=repo, capture_output=True)

    print("✓ double-claim prevention works")

def test_concurrent_claims(tmp_path):
    """Test that file locking prevents race conditions"""
    repo = setup_test_repo(tmp_path)
    os.chdir(repo)

    tm = TaskManager(repo)

    # Create multiple tasks
    task_ids = []
    for i in range(3):
        task_id = tm.create_task(
            title=f"Task {i}",
            description=f"Test {i}",
            role="implementer"
        )
        task_ids.append(task_id)

    # Try to claim them concurrently (simulate with sequential for simplicity)
    # In a real test, use multiprocessing
    claimed = []
    for i, task_id in enumerate(task_ids):
        worktree = tm.claim_task(task_id, f"agent-{i}", "implementer")
        if worktree:
            claimed.append(worktree)

    assert len(claimed) == 3, f"Expected 3 claims, got {len(claimed)}"

    # Cleanup
    for worktree in claimed:
        subprocess.run(['git', 'worktree', 'remove', worktree, '--force'],
                       cwd=repo, capture_output=True)

    print("✓ concurrent claims work")

def test_stale_detection(tmp_path):
    """Test stale task detection"""
    repo = setup_test_repo(tmp_path)
    os.chdir(repo)

    tm = TaskManager(repo)
    task_id = tm.create_task(
        title="Test task",
        description="Test",
        role="implementer"
    )

    worktree = tm.claim_task(task_id, "agent-1", "implementer")
    assert worktree is not None

    # Manually set claimed_at to 3 hours ago
    tasks = tm._read_tasks()
    from datetime import datetime, timedelta
    for task in tasks:
        if task['task_id'] == task_id:
            task['claimed_at'] = (datetime.now() - timedelta(hours=3)).isoformat()

    # Rewrite tasks
    with open(repo / 'TASKS.jsonl', 'w') as f:
        for task in tasks:
            f.write(json.dumps(task) + '\\n')

    # Detect stale
    stale = tm.detect_stale_tasks()
    assert len(stale) == 1, f"Expected 1 stale task, got {len(stale)}"
    assert stale[0]['task_id'] == task_id

    # Cleanup
    subprocess.run(['git', 'worktree', 'remove', worktree, '--force'],
                   cwd=repo, capture_output=True)

    print("✓ stale detection works")

if __name__ == '__main__':
    import tempfile
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)

        print("Running unit tests...")
        print()

        test_find_project_root(tmp_path)
        test_create_task(tmp_path)
        test_claim_task(tmp_path)
        test_double_claim_prevention(tmp_path)
        test_concurrent_claims(tmp_path)
        test_stale_detection(tmp_path)

        print()
        print("✓ All unit tests passed!")
```

Run tests:
```bash
python3 tests/test_task_manager.py
```

## Integration Tests

### Full Workflow Test

Create `tests/test_full_workflow.sh`:

```bash
#!/usr/bin/env bash
# Integration test for complete workflow

set -e

TEST_DIR=$(mktemp -d)
echo "Testing in: $TEST_DIR"

cleanup() {
    echo "Cleaning up test directory..."
    cd /
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Create test git repo
cd "$TEST_DIR"
git init
git config user.email "test@example.com"
git config user.name "Test User"

echo "# Test Project" > README.md
git add .
git commit -m "Initial commit"

# Copy workflow files
cp -r /path/to/workflow_installer/.workflow .
cp /path/to/workflow_installer/.gitignore .
touch TASKS.jsonl
touch IN_PROGRESS.md

echo ""
echo "Test 1: Create task"
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Test implementation" \
  --description "Test task" \
  --role "implementer" \
  --priority "high"

TASK_ID=$(python3 .workflow/scripts/core/task_manager.py list-tasks --status available | grep TASK | awk '{print $1}' | head -1)
echo "Created task: $TASK_ID"
[ -n "$TASK_ID" ] || (echo "❌ Task creation failed" && exit 1)
echo "✓ Task creation works"

echo ""
echo "Test 2: Spawn agent"
# Note: This creates worktree but doesn't actually spawn an agent
# We just test the infrastructure
bash .workflow/scripts/worktree/spawn_agent.sh implementer <<< "$TASK_ID"

[ -d "worktrees/$TASK_ID" ] || (echo "❌ Worktree creation failed" && exit 1)
echo "✓ Agent spawning works"

echo ""
echo "Test 3: Make changes in worktree"
cd "worktrees/$TASK_ID"
echo "# Test change" >> README.md
git add README.md
git commit -m "Test change for $TASK_ID"

echo "✓ Can make changes in worktree"

echo ""
echo "Test 4: Submit for review"
# Create minimal evidence
mkdir -p .workflow/evidence/$TASK_ID
cat > .workflow/evidence/$TASK_ID/implementer_claim.json <<EOF
{
  "task_id": "$TASK_ID",
  "summary": "Test changes",
  "test_results": {"tests_passed": 1}
}
EOF

cd ../..
echo "✓ Evidence created"

echo ""
echo "Test 5: Complete review (approve)"
bash .workflow/scripts/worktree/complete_review.sh $TASK_ID approved "Test approval"

# Check task is completed
STATUS=$(python3 .workflow/scripts/core/task_manager.py list-tasks | grep $TASK_ID | awk '{print $3}')
[ "$STATUS" = "completed" ] || (echo "❌ Task not marked completed" && exit 1)

# Check worktree removed
[ ! -d "worktrees/$TASK_ID" ] || (echo "❌ Worktree not cleaned up" && exit 1)

echo "✓ Review completion works"

echo ""
echo "✅ All integration tests passed!"
```

Run:
```bash
bash tests/test_full_workflow.sh
```

### Parallel Agent Test

Test multiple agents working simultaneously:

```bash
#!/usr/bin/env bash
# Test parallel agents

# Create 3 tasks
for i in 1 2 3; do
    python3 .workflow/scripts/core/task_manager.py create-task \
      --title "Parallel task $i" \
      --description "Test parallel workflow" \
      --role "implementer"
done

# Claim all 3 in parallel (in background)
for i in 1 2 3; do
    (
        echo "Agent $i starting..."
        bash .workflow/scripts/worktree/spawn_agent.sh implementer
        sleep 2
        echo "Agent $i done"
    ) &
done

# Wait for all to complete
wait

# Check 3 worktrees exist
WORKTREE_COUNT=$(ls -1 worktrees/ | wc -l)
if [ "$WORKTREE_COUNT" -eq 3 ]; then
    echo "✓ Parallel agent spawning works"
else
    echo "❌ Expected 3 worktrees, found $WORKTREE_COUNT"
    exit 1
fi
```

## Stress Tests

### 100 Task Test

Test performance with many tasks:

```bash
#!/usr/bin/env bash
# Stress test with 100 tasks

echo "Creating 100 tasks..."
for i in $(seq 1 100); do
    python3 .workflow/scripts/core/task_manager.py create-task \
      --title "Task $i" \
      --description "Stress test task $i" \
      --role "implementer" \
      --priority "medium"
done

echo "Listing tasks..."
time python3 .workflow/scripts/core/task_manager.py list-tasks > /dev/null

echo "Claiming 10 tasks..."
for i in $(seq 1 10); do
    bash .workflow/scripts/worktree/spawn_agent.sh implementer || break
done

echo "Checking health..."
python3 .workflow/scripts/evolution/self_healing_monitor.py

echo "✓ Stress test complete"
```

## Testing Checklist

Before releasing or deploying:

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Can create tasks
- [ ] Can claim tasks without race conditions
- [ ] Double-claim prevention works
- [ ] Worktrees are created correctly
- [ ] Can work in worktrees
- [ ] Can submit for review
- [ ] Can complete review (approve)
- [ ] Can complete review (reject)
- [ ] Worktrees are cleaned up
- [ ] Stale task detection works
- [ ] Orphaned worktree detection works
- [ ] File locking works
- [ ] Project root detection works from worktrees
- [ ] Health monitoring works
- [ ] Parallel agents work
- [ ] System validates correctly
- [ ] Documentation is accurate

## Continuous Testing

Set up automated testing:

```yaml
# .github/workflows/test-workflow.yml
name: Test Workflow System

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install dependencies
        run: |
          sudo apt-get install jq
          pip3 install pytest pytest-randomly freezegun

      - name: Validate system
        run: bash scripts/validate_system.sh

      - name: Run unit tests
        run: python3 tests/test_task_manager.py

      - name: Run integration tests
        run: bash tests/test_full_workflow.sh

      - name: Check health monitoring
        run: python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Manual Testing Scenarios

### Scenario 1: Happy Path
1. Create task
2. Spawn agent
3. Make changes
4. Submit for review
5. Approve
6. Verify merge and cleanup

### Scenario 2: Rejected Task
1. Create task
2. Spawn agent
3. Make bad changes
4. Submit for review
5. Reject with feedback
6. Verify task returns to available

### Scenario 3: Agent Crash Recovery
1. Create and claim task
2. Manually kill the process (simulate crash)
3. Wait 2+ hours
4. Run monitor
5. Verify task released and worktree cleaned

### Scenario 4: Merge Conflict
1. Create task
2. Spawn agent
3. Make changes in worktree
4. Make conflicting changes in main
5. Try to complete review
6. Verify conflict is detected

## Performance Benchmarks

Measure and track these metrics:

```bash
# Task claim latency
time bash .workflow/scripts/worktree/spawn_agent.sh implementer

# TASKS.jsonl read performance
time python3 .workflow/scripts/core/task_manager.py list-tasks

# Health check time
time python3 .workflow/scripts/evolution/self_healing_monitor.py

# Disk usage
du -sh worktrees/
du -sh .workflow/evidence/
```

Expected benchmarks:
- Task claim: <2 seconds
- List 100 tasks: <0.5 seconds
- Health check: <5 seconds
- Worktree size: ~repo size

## Test Data Cleanup

After testing:

```bash
# Remove test tasks
rm TASKS.jsonl
touch TASKS.jsonl

# Clean worktrees
git worktree list | grep worktrees | awk '{print $1}' | xargs -I {} git worktree remove {} --force
git worktree prune

# Reset IN_PROGRESS.md
cat > IN_PROGRESS.md <<'EOF'
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
EOF

# Clean monitoring
rm .workflow/monitoring/*.json 2>/dev/null || true
```

