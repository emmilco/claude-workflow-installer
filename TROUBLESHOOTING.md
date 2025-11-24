# Troubleshooting Guide

This guide covers common issues, failure scenarios, and recovery procedures for the multi-agent workflow system.

## Quick Diagnosis

```bash
# Check system health
python3 .workflow/scripts/evolution/self_healing_monitor.py

# View dashboard
cat .workflow/monitoring/DASHBOARD.md

# List all tasks and their states
python3 .workflow/scripts/core/task_manager.py list-tasks

# Check what's currently in progress
cat IN_PROGRESS.md

# Check for orphaned worktrees
git worktree list
ls -la worktrees/
```

## Common Issues

### 1. "jq: command not found"

**Symptom:** spawn_agent.sh fails with "jq: command not found"

**Cause:** jq is not installed

**Solution:**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Fedora/RHEL
sudo dnf install jq
```

**Prevention:** Run install.sh which checks for jq

### 2. "ERROR: At maximum concurrency (6)"

**Symptom:** Cannot claim new tasks

**Cause:** Already have 6 tasks in progress

**Diagnosis:**
```bash
cat IN_PROGRESS.md
# Check how many tasks are actually active
```

**Solutions:**

**Option A: Wait for tasks to complete**
```bash
# Check if any are close to done
cat IN_PROGRESS.md
```

**Option B: Increase concurrency limit**
```bash
# Edit .workflow/scripts/core/task_manager.py
# Change: self.max_concurrent = 6
# To: self.max_concurrent = 8
```

**Option C: Force-release a stuck task**
```bash
python3 .workflow/scripts/core/task_manager.py force-release \
  --task-id TASK-XXX \
  --reason "Agent crashed"
```

**Prevention:**
- Run monitor regularly to auto-release stale tasks
- Don't spawn more agents than your team can actively work on

### 3. "ERROR: Task TASK-XXX is not available (status: claimed)"

**Symptom:** Trying to claim a task that's already claimed

**Cause:** Another agent claimed it first (or you're trying to claim your own task again)

**Diagnosis:**
```bash
# Check task status
python3 .workflow/scripts/core/task_manager.py list-tasks | grep TASK-XXX

# Check who claimed it
cat IN_PROGRESS.md | grep TASK-XXX
```

**Solutions:**

**Option A: Get next available task**
```bash
python3 .workflow/scripts/core/task_manager.py get-next-task --role implementer
```

**Option B: If task is stale, force release it**
```bash
python3 .workflow/scripts/core/task_manager.py detect-stale
# If task is listed as stale:
python3 .workflow/scripts/core/task_manager.py force-release --task-id TASK-XXX --reason "stale"
```

### 4. "ERROR: Failed to create worktree: fatal: 'worktrees/TASK-XXX' already exists"

**Symptom:** Worktree directory exists but task shows as available

**Cause:** Previous claim failed partway through, leaving orphaned worktree

**Diagnosis:**
```bash
git worktree list
ls -la worktrees/TASK-XXX/
```

**Solution:**
```bash
# Remove the orphaned worktree
git worktree remove worktrees/TASK-XXX --force

# If that fails, remove manually
rm -rf worktrees/TASK-XXX
git worktree prune

# Now claim the task again
bash .workflow/scripts/worktree/spawn_agent.sh implementer
```

**Prevention:** The updated task_manager.py now cleans up worktrees on claim failure

### 5. Tests pass for implementer but fail for reviewer

**Symptom:** Implementer's tests pass, but when reviewer re-runs them, they fail

**Cause:** Non-deterministic tests

**Diagnosis:**
```bash
# Check if test uses random seed
cat .workflow/evidence/TASK-XXX/implementer_claim.json | jq '.test_seed'

# Try running tests with same seed
pytest tests/ --randomly-seed=42

# Check for timing dependencies
grep -r "sleep\|time\|datetime.now\|random" tests/
```

**Common culprits:**
- `random.random()` without seed set
- `datetime.now()` in tests
- `time.sleep()` with race conditions
- External API calls
- Filesystem dependencies

**Solutions:**

**For random values:**
```python
import random
random.seed(42)  # Use fixed seed in tests

# Or use pytest-randomly with seed
pytest --randomly-seed=42
```

**For timestamps:**
```python
from freezegun import freeze_time

@freeze_time("2025-11-23 12:00:00")
def test_timestamp():
    # datetime.now() will always return frozen time
    pass
```

**For external dependencies:**
```python
from unittest.mock import patch, Mock

@patch('requests.get')
def test_api_call(mock_get):
    mock_get.return_value = Mock(status_code=200, json=lambda: {"data": "fixed"})
    # Test uses mocked response
```

**For file system:**
```python
import tempfile
import pytest

@pytest.fixture
def temp_dir():
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir
    # Auto-cleaned up after test
```

**Prevention:**
- Always use `pytest --randomly-seed=X`
- Mock external dependencies
- Use freezegun for time
- Avoid sleep() in tests

### 6. "Permission denied" when running scripts

**Symptom:** `bash: .workflow/scripts/worktree/spawn_agent.sh: Permission denied`

**Cause:** Scripts not executable

**Solution:**
```bash
# Make all scripts executable
find .workflow/scripts -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
find .workflow/hooks -type f -name "*.sh" -exec chmod +x {} +

# Or make specific script executable
chmod +x .workflow/scripts/worktree/spawn_agent.sh
```

**Prevention:** install.sh sets permissions automatically

### 7. "ERROR: Failed to update task state: [Errno 11] Resource temporarily unavailable"

**Symptom:** Task claim fails with resource lock error

**Cause:** Another process has the file lock

**Diagnosis:**
```bash
# Check if lock file exists
ls -la .tasks.lock

# Check if any process has it open
lsof .tasks.lock
```

**Solutions:**

**Option A: Wait a moment and retry**
```bash
# Lock should release in <1 second normally
sleep 2
bash .workflow/scripts/worktree/spawn_agent.sh implementer
```

**Option B: Remove stale lock (if no process has it)**
```bash
# Only if lsof shows no process
rm .tasks.lock
```

**Prevention:**
- Locks are released automatically
- If locks persist, there may be a bug (report it)

### 8. Worktrees accumulating and using too much disk space

**Symptom:** `df -h` shows high disk usage, many directories in `worktrees/`

**Diagnosis:**
```bash
# Check worktree count
ls worktrees/ | wc -l

# Check disk usage
du -sh worktrees/

# Find orphaned worktrees
git worktree list
# Compare with IN_PROGRESS.md
```

**Solutions:**

**Option A: Run self-healing monitor**
```bash
# Auto-detects and cleans orphaned worktrees
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

**Option B: Manual cleanup**
```bash
# Remove specific worktree
git worktree remove worktrees/TASK-XXX

# Remove all worktrees not in IN_PROGRESS.md
for dir in worktrees/*/; do
    task_id=$(basename "$dir")
    if ! grep -q "$task_id" IN_PROGRESS.md; then
        echo "Removing orphaned: $task_id"
        git worktree remove "worktrees/$task_id" --force || rm -rf "worktrees/$task_id"
    fi
done

# Prune git's worktree records
git worktree prune
```

**Prevention:**
- Run monitor regularly (hourly cron)
- Complete or release tasks promptly
- Don't manually kill agents without cleanup

### 9. "ERROR: Task TASK-XXX not found"

**Symptom:** Trying to claim or complete a non-existent task

**Cause:** Task ID typo, or task was deleted

**Diagnosis:**
```bash
# List all tasks to find correct ID
python3 .workflow/scripts/core/task_manager.py list-tasks

# Search TASKS.jsonl directly
grep "TASK-" TASKS.jsonl
```

**Solution:**
```bash
# Use correct task ID
# Or create the task if it should exist
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Task title" \
  --description "Description" \
  --role "implementer"
```

### 10. Git merge conflicts when completing review

**Symptom:** `complete_review.sh` fails with merge conflict

**Cause:** Main branch changed since task was claimed

**Diagnosis:**
```bash
cd worktrees/TASK-XXX
git fetch origin main
git log main..HEAD --oneline  # Your changes
git log HEAD..main --oneline  # Main's changes
```

**Solutions:**

**Option A: Rebase and resubmit**
```bash
cd worktrees/TASK-XXX

# Rebase onto latest main
git fetch origin main
git rebase main

# If conflicts, resolve them
git status
# Edit conflicting files
git add <files>
git rebase --continue

# Re-run tests to ensure still passing
pytest tests/ --randomly-seed=42

# Resubmit for review
bash .workflow/scripts/worktree/submit_for_review.sh TASK-XXX
```

**Option B: Reject and have implementer rebase**
```bash
bash .workflow/scripts/worktree/complete_review.sh TASK-XXX rejected \
  "Main branch has changed. Please rebase onto latest main and resubmit."
```

**Prevention:**
- Keep tasks small (complete within hours, not days)
- Rebase regularly during long-running tasks
- Coordinate with team on overlapping work

## Recovery Procedures

### Corrupted TASKS.jsonl

**Symptom:** `json.JSONDecodeError` when running task_manager.py

**Diagnosis:**
```bash
# Find corrupted line
python3 -c "
import json
with open('TASKS.jsonl') as f:
    for i, line in enumerate(f, 1):
        try:
            json.loads(line.strip())
        except json.JSONDecodeError as e:
            print(f'Line {i}: {e}')
            print(f'Content: {line}')
"
```

**Solution:**
```bash
# Backup current file
cp TASKS.jsonl TASKS.jsonl.backup.$(date +%s)

# Remove corrupted line(s) manually
nano TASKS.jsonl

# Or filter out invalid lines
python3 -c "
import json
with open('TASKS.jsonl') as fin, open('TASKS.jsonl.fixed', 'w') as fout:
    for line in fin:
        try:
            json.loads(line.strip())
            fout.write(line)
        except json.JSONDecodeError:
            print(f'Skipped bad line: {line[:50]}...')
"
mv TASKS.jsonl.fixed TASKS.jsonl
```

**Prevention:**
- File locking prevents most corruption
- Regular backups (git commit TASKS.jsonl to a backup branch)
- Monitor file size for sudden changes

### Lost IN_PROGRESS.md

**Symptom:** IN_PROGRESS.md missing or empty

**Cause:** Accidentally deleted or reset

**Solution:**
```bash
# Regenerate from TASKS.jsonl
python3 -c "
import sys
sys.path.insert(0, '.workflow/scripts/core')
from task_manager import TaskManager

tm = TaskManager()
tasks = tm._read_tasks()
in_progress = [t for t in tasks if t['status'] == 'claimed']

content = '''# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
'''
for t in in_progress:
    content += f\"| {t['task_id']} | {t.get('claimed_by', 'unknown')} | {t['role']} | {t.get('claimed_at', 'unknown')} | {t.get('worktree_path', 'unknown')} | in_progress |\\n\"

with open('IN_PROGRESS.md', 'w') as f:
    f.write(content)

print('IN_PROGRESS.md regenerated')
"
```

### Rollback a Bad Merge

**Symptom:** Merged task broke main branch

**Cause:** Tests passed in worktree but broke integration

**Solution:**

**Option A: Revert the merge commit**
```bash
# Find the merge commit
git log --oneline --merges -n 5

# Revert it
git revert -m 1 <merge-commit-hash>
git push origin main

# Create new task to fix the issue
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Fix issues from TASK-XXX" \
  --description "Reverted TASK-XXX, now fix properly" \
  --role "implementer" \
  --priority "high"
```

**Option B: Reset main (if not pushed)**
```bash
# Only if you haven't pushed yet!
git reset --hard HEAD~1
```

**Prevention:**
- Run integration tests before merging
- Have reviewer verify locally
- Use feature flags for risky changes

### Restore from Backup

**When to use:** Complete workflow failure, corrupted state

**Backup strategy:**
```bash
# Create backup branch for state files
git checkout -b workflow-state-backup
git add TASKS.jsonl IN_PROGRESS.md DECISIONS.md
git commit -m "Workflow state backup $(date)"
git push origin workflow-state-backup

# Do this daily via cron
```

**Restore:**
```bash
# Stop all agents
# Delete current state
rm TASKS.jsonl IN_PROGRESS.md

# Restore from backup branch
git checkout workflow-state-backup -- TASKS.jsonl IN_PROGRESS.md DECISIONS.md

# Clean up orphaned worktrees
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Debugging Tips

### Enable Verbose Mode

**For Python scripts:**
```bash
# Add --verbose flag (if implemented)
python3 .workflow/scripts/core/task_manager.py --verbose list-tasks

# Or use Python debugger
python3 -m pdb .workflow/scripts/core/task_manager.py list-tasks
```

**For Bash scripts:**
```bash
# Run with bash -x for trace
bash -x .workflow/scripts/worktree/spawn_agent.sh implementer

# Or add set -x to script temporarily
```

### Inspect State Files

```bash
# Pretty-print TASKS.jsonl
cat TASKS.jsonl | jq '.'

# Find specific task
cat TASKS.jsonl | jq 'select(.task_id == "TASK-XXX")'

# Count tasks by status
cat TASKS.jsonl | jq -r '.status' | sort | uniq -c

# Find old tasks (>7 days)
cat TASKS.jsonl | jq 'select(.created_at < "'$(date -d '7 days ago' -Idate)'")'
```

### Monitor File Locks

```bash
# Check if lock file is held
lsof .tasks.lock

# Watch for lock contention
watch -n 1 'lsof .tasks.lock'

# Check how long lock file has existed
stat .tasks.lock
```

### Test Git Worktree Operations

```bash
# List all worktrees
git worktree list

# Check worktree status
cd worktrees/TASK-XXX
git status
git log --oneline -n 5

# Test merge without committing
git merge --no-commit --no-ff main
git merge --abort  # Undo test merge
```

## Performance Issues

### Slow Task Listing

**Symptom:** `list-tasks` takes >1 second

**Cause:** TASKS.jsonl has many entries

**Diagnosis:**
```bash
# Count tasks
wc -l TASKS.jsonl

# Check file size
ls -lh TASKS.jsonl
```

**Solution:**
```bash
# Archive completed tasks older than 30 days
python3 -c "
import json
from datetime import datetime, timedelta

cutoff = (datetime.now() - timedelta(days=30)).isoformat()

with open('TASKS.jsonl') as fin:
    tasks = [json.loads(line) for line in fin if line.strip()]

active = [t for t in tasks if t['status'] != 'completed' or t.get('completed_at', '9999') > cutoff]
archived = [t for t in tasks if t['status'] == 'completed' and t.get('completed_at', '') <= cutoff]

with open('TASKS.jsonl', 'w') as f:
    for t in active:
        f.write(json.dumps(t) + '\\n')

with open('TASKS_archive.jsonl', 'a') as f:
    for t in archived:
        f.write(json.dumps(t) + '\\n')

print(f'Archived {len(archived)} tasks, kept {len(active)} active')
"
```

### High Disk Usage

See issue #8 above (worktrees accumulating)

**Additional:**
```bash
# Archive old evidence files
find .workflow/evidence -type d -mtime +30 -exec tar -czf {}.tar.gz {} \; -exec rm -rf {} \;

# Clean up old monitoring files
find .workflow/monitoring -name "health-*.json" -mtime +7 -delete
find .workflow/monitoring -name "alert-*.json" -mtime +7 -delete
```

## Getting Help

If you encounter an issue not covered here:

1. **Check system health:**
   ```bash
   python3 .workflow/scripts/evolution/self_healing_monitor.py
   cat .workflow/monitoring/DASHBOARD.md
   ```

2. **Collect diagnostic info:**
   ```bash
   # Create a debug report
   cat > debug_report.txt <<EOF
   # System Info
   $(uname -a)
   $(python3 --version)
   $(git --version)
   $(jq --version)

   # Workflow State
   $(cat IN_PROGRESS.md)
   $(wc -l TASKS.jsonl)
   $(ls -la worktrees/)
   $(git worktree list)

   # Recent errors (if logging implemented)
   $(tail -50 .workflow/monitoring/errors.log)
   EOF
   ```

3. **Check ARCHITECTURE.md** for design explanations

4. **Search closed issues** in the repo

5. **Open a new issue** with debug report attached

