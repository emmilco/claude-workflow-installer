# Multi-Agent Workflow - Architecture Guide

## Overview

This document explains the technical architecture, design decisions, and internals of the multi-agent workflow system.

## Core Architecture Principles

### 1. Git Worktrees for Isolation

**Why:** Multiple agents working in parallel would conflict if sharing the same working directory.

**How it works:**
- Main repo at project root contains shared state (TASKS.jsonl, IN_PROGRESS.md)
- Each claimed task gets a separate worktree at `worktrees/TASK-XXX/`
- Worktrees share the same `.git` database but have independent working directories
- Scripts are tracked in git, so each worktree has its own copy
- State files are NOT git-tracked (in .gitignore) so they remain centralized

**Finding project root from worktrees:**
```python
# Worktrees have a .git file (not directory) that points to main repo
# Format: "gitdir: /path/to/main/.git/worktrees/TASK-XXX"
# task_manager.py auto-detects this and finds the main repo
```

### 2. Task State Machine

**Task Lifecycle:**
```
created (available)
    ↓ claim_task()
claimed (in_progress)
    ↓ submit_for_review()
in_review
    ↓ complete_review(approved)
    |     → merge to main → completed
    ↓ complete_review(rejected)
    → back to available (or rejected state for analysis)
```

**States:**
- `available` - Ready to be claimed by an agent
- `claimed` - Agent is working on it (shown as "in_progress" in IN_PROGRESS.md)
- `in_review` - Submitted for review (currently implicit, could be explicit)
- `completed` - Merged to main and done
- `rejected` - Failed review, needs rework (returns to available or tracked separately)

**State storage:**
- `TASKS.jsonl` - Canonical source of truth for task state
- `IN_PROGRESS.md` - Human-readable view of active tasks (derived from TASKS.jsonl)

### 3. File Locking for Atomicity

**Problem:** Multiple agents claiming tasks simultaneously could double-claim the same task.

**Solution:** POSIX file locking with fcntl
```python
with open('.tasks.lock', 'w') as lockf:
    fcntl.flock(lockf.fileno(), fcntl.LOCK_EX)
    # Read-modify-write operation here
    fcntl.flock(lockf.fileno(), fcntl.LOCK_UN)
```

**Why not SQLite:** Need human-readable state files for debugging and git-based workflows.

### 4. Project Root Detection

**Problem:** Scripts need to find TASKS.jsonl whether run from project root or worktree.

**Solution:** Traverse upward looking for .git directory
- If `.git` is a directory → we're in main repo
- If `.git` is a file → we're in worktree, parse it to find main repo
- Fallback to cwd() if no .git found

**Benefit:** Commands work from anywhere in the project tree.

## Data Structures

### TASKS.jsonl Format

Each line is a JSON object representing one task:

```json
{
  "task_id": "TASK-20251123-0042",
  "title": "Implement user authentication",
  "description": "Add JWT-based auth with refresh tokens",
  "role": "implementer",
  "status": "claimed",
  "priority": "high",
  "files_in_scope": ["src/auth/**/*.py", "tests/test_auth.py"],
  "acceptance_criteria": [
    "unit_tests pass",
    "integration_smoke pass",
    "reviewer approval"
  ],
  "created_at": "2025-11-23T10:30:00Z",
  "created_by": "architect-001",
  "claimed_by": "implementer-1732363800-12345",
  "claimed_at": "2025-11-23T11:00:00Z",
  "completed_at": null,
  "worktree_path": "worktrees/TASK-20251123-0042"
}
```

**Why JSONL (not JSON array):**
- Append-only friendly
- Can stream/parse line by line
- Corrupt lines don't break entire file
- Easy to grep/search

**Tradeoff:** No indexing, O(n) reads. Acceptable for <1000 tasks. At scale, migrate to SQLite.

### Evidence Package Format

`implementer_claim.json`:
```json
{
  "claim_id": "TASK-001-claim-1732363800",
  "task_id": "TASK-001",
  "agent_id": "implementer-1732363800-12345",
  "role": "implementer",
  "timestamp": "2025-11-23T11:30:00Z",
  "summary": "Implemented JWT auth with refresh token rotation",
  "files_modified": ["src/auth/jwt.py", "tests/test_jwt.py"],
  "test_command": "pytest tests/test_jwt.py --randomly-seed=42",
  "test_seed": 42,
  "test_results": {
    "tests_run": 15,
    "tests_passed": 15,
    "tests_failed": 0,
    "duration_seconds": 3.2
  },
  "evidence_files": [
    "git_status.txt",
    "changes.diff",
    "test_output.txt"
  ],
  "evidence_hash": "sha256:abc123...",
  "confidence": 0.85,
  "notes": "All tests passing with fixed seed. Ready for review."
}
```

**Note on evidence_hash:** This is a content hash for detecting evidence tampering, NOT for verification of test determinism. See "SHA256 Verification" section below.

## SHA256 Verification Strategy

### The Problem

Original design: Hash test output and verify integrator gets same hash.

**Why this fails:**
- Timestamps in test output
- Process IDs in temp files
- Memory addresses in object reprs
- Nondeterministic test ordering
- Floating point precision differences

### Current Solution

1. **Test seeds required** - `test_seed` field in claim ensures deterministic randomness
2. **Normalize test output** - Strip timestamps, PIDs, addresses before hashing
3. **Hash structured data, not raw output** - Hash the test_results object (counts, pass/fail), not the full output text
4. **Evidence hash for tamper detection** - Hash the evidence files to detect tampering, separate from verification
5. **Manual review as fallback** - Reviewer examines diffs if hashes don't match

### Improved Verification Approach

```python
def create_verification_hash(test_results: dict, files_modified: list) -> str:
    """Hash only deterministic aspects of evidence"""
    stable_data = {
        'test_seed': test_results.get('test_seed'),
        'tests_passed': test_results.get('tests_passed'),
        'tests_failed': test_results.get('tests_failed'),
        'files_modified_count': len(files_modified),
        'file_hashes': [hash_file(f) for f in files_modified]
    }
    return hashlib.sha256(json.dumps(stable_data, sort_keys=True).encode()).hexdigest()
```

**Still fragile for:**
- Environment differences (OS, Python version)
- Dependency version changes
- External service states

**Recommendation:** Use SHA256 as a smoke test. Mismatches trigger manual review, not automatic rejection.

## Concurrency and Coordination

### Concurrency Limit

**Default:** 6 concurrent tasks

**Rationale:**
- Balances parallelism with API costs
- Prevents resource exhaustion
- Allows reasonable queue depth monitoring

**How to choose:**
- Small teams (1-3 devs): 2-4 tasks
- Medium teams (4-10 devs): 4-8 tasks
- Large teams (10+ devs): 8-12 tasks
- Consider: API rate limits, disk space, review bandwidth

### Task Claiming Protocol

1. Agent calls `get-next-task --role implementer`
2. Task manager returns highest priority available task for that role
3. Agent calls `claim-task --task-id TASK-XXX`
4. Task manager:
   - Acquires file lock
   - Checks concurrency limit
   - Checks task is still available (double-claim protection)
   - Creates worktree
   - Updates task status to 'claimed'
   - Adds to IN_PROGRESS.md
   - Releases lock
5. Agent begins work in worktree

**Failure modes handled:**
- Concurrency limit reached → Agent waits or does other work
- Task already claimed → Agent gets next task
- Worktree creation fails → No state change, task remains available
- State update fails after worktree created → Worktree cleaned up automatically

### Self-Healing

**Stale task detection:**
- Tasks claimed >2 hours with no updates → marked stale
- Monitor auto-releases stale tasks back to available
- Original agent's worktree remains for debugging

**Orphaned worktree cleanup:**
- Worktrees in filesystem but not in IN_PROGRESS.md → orphaned
- Monitor detects and removes them
- Branch is also deleted (safe because not yet merged)

**Health monitoring:**
- Collects metrics: completion rate, cycle time, queue depth, utilization
- Computes health score (0-1)
- Detects anomalies vs historical baseline
- Triggers alerts when health degrades
- Generates dashboard in markdown

## Cost Considerations

### API Usage

**Warning:** Running 6 parallel agents means 6 simultaneous Claude API calls.

**Cost factors:**
- Model: Sonnet is cheaper than Opus
- Task complexity: Simple tasks use fewer tokens
- Evidence size: Large diffs cost more to review
- Prompt length: Role prompts add to context

**Estimation:**
- Simple task (200 LOC change): ~$0.10-0.30 per task
- Medium task (500 LOC change): ~$0.30-0.80 per task
- Complex task (1000+ LOC): ~$1.00-3.00 per task

**6 concurrent agents, 10 tasks/day:**
- Low estimate: $6-18/day
- High estimate: $60-180/day

**Mitigation:**
- Start with 2-3 agents, not 6
- Use cheaper models for simple tasks
- Batch review multiple small tasks
- Monitor costs via API usage dashboard

### Resource Usage

**Disk space:**
- Each worktree: ~size of repo (can be 100MB-1GB+)
- Evidence files: ~1-10MB per task
- 6 concurrent tasks: 600MB-6GB+ in worktrees
- Historical evidence: grows over time

**Recommendations:**
- Archive old evidence (>30 days)
- Clean up completed task worktrees
- Monitor disk usage in health dashboard

## Agent "Spawning" Clarification

**Terminology note:** "Spawn agent" is misleading. It doesn't launch an autonomous agent.

**What actually happens:**
1. `spawn_agent.sh` claims a task
2. Creates a worktree
3. Prints instructions for human to follow
4. Human manually CDs into worktree
5. Human works on task (possibly with Claude Code assistance)
6. Human manually runs submit_for_review.sh when done

**It's workspace setup, not agent automation.**

**For true multi-agent coordination:**
- You need 6 separate Claude Code sessions (6 terminal windows/tmux panes)
- Each session runs in its own worktree
- Coordination happens via shared TASKS.jsonl file

## Security Considerations

### Current State (Not Production-Ready)

**No access control:**
- Anyone who can run scripts can claim/complete tasks
- No authentication
- No audit log of who did what

**Input validation:**
- Task titles/descriptions not sanitized
- Could potentially cause issues if used in shell commands

**File permissions:**
- State files readable/writable by anyone with access
- Evidence directories not access-controlled

### Recommendations for Production

1. **Add authentication:**
   - Require agent IDs to be validated
   - Map agent IDs to real users
   - Log all actions with user attribution

2. **Input sanitization:**
   - Validate task IDs match expected format
   - Escape shell metacharacters in titles/descriptions
   - Limit string lengths

3. **File permissions:**
   - Make state files group-writable only
   - Restrict evidence directories to workflow group
   - Use umask for secure file creation

4. **Audit logging:**
   - Log all state changes to append-only log
   - Include timestamp, user, action, task ID
   - Monitor for suspicious patterns

## Performance and Scalability

### Current Limits

**Tested up to:**
- 50 tasks in TASKS.jsonl
- 6 concurrent agents
- 10 completed tasks per day

**Expected breaking points:**
- 500+ tasks: JSONL reads become slow (multi-second)
- 1000+ tasks: Need to migrate to SQLite or index
- 20+ concurrent agents: File locking contention
- 100+ completed tasks: Evidence directory large

### Scaling Strategies

**For more tasks:**
- Archive completed tasks to TASKS_archive.jsonl
- Keep only active/recent in TASKS.jsonl
- Build index file for fast lookups

**For more agents:**
- Shard tasks by role/priority
- Use separate TASKS files per shard
- Aggregate in monitoring dashboard

**For better performance:**
- Cache parsed TASKS.jsonl in memory (with file mtime check)
- Use finer-grained locking (per-task, not whole file)
- Batch state updates

## Testing the Workflow System

### Unit Tests

Test task_manager.py in isolation:
```bash
python3 -m pytest tests/test_task_manager.py
```

**Key scenarios to test:**
- Task creation with valid/invalid inputs
- Concurrent task claiming (race conditions)
- Stale task detection
- File locking behavior

### Integration Tests

Test full workflow:
```bash
./tests/integration/test_full_workflow.sh
```

**Scenarios:**
- Create task → claim → work → submit → review → merge
- Multiple parallel agents claiming different tasks
- Agent crash recovery (stale task cleanup)
- Evidence verification mismatch handling

### Stress Tests

Test at scale:
```bash
./tests/stress/test_100_tasks.sh
```

**Metrics to monitor:**
- Task claim latency with file contention
- TASKS.jsonl read/write performance
- Worktree creation time
- Disk space usage

## Troubleshooting Decision Tree

**Task claim fails:**
1. Check concurrency limit (cat IN_PROGRESS.md)
2. Check task still available (list-tasks)
3. Check disk space for worktree
4. Check git worktree list for conflicts

**Tests pass for implementer but fail for reviewer:**
1. Check test seed is set (test_command has --randomly-seed)
2. Check for timestamps/PIDs in test output
3. Check for external dependencies (network, filesystem)
4. Check environment differences (Python version, OS)

**Worktrees accumulating:**
1. Run monitor to detect orphans
2. Check IN_PROGRESS.md vs filesystem
3. Manually clean: git worktree remove TASK-XXX

**Performance degrading:**
1. Check TASKS.jsonl size (wc -l TASKS.jsonl)
2. Archive old completed tasks
3. Check disk space (df -h)
4. Check for stuck file locks (lsof .tasks.lock)

## Design Decisions Log

### Why JSONL instead of JSON array?
- Append-only friendly, less corruption risk
- Can parse incrementally
- Easier to grep/edit manually
- Tradeoff: No built-in indexing

### Why not use a database?
- Wanted human-readable state files
- Git-friendly (can diff TASKS.jsonl)
- No external dependencies
- Simple for small-scale use
- Tradeoff: Performance at scale

### Why file locking instead of optimistic concurrency?
- Simpler to implement correctly
- Works across processes without coordination
- Low contention expected (<10 agents)
- Tradeoff: Blocks on contention

### Why worktrees instead of branches?
- Parallel work without switching contexts
- No chance of accidentally working in wrong branch
- Clean isolation of changes
- Tradeoff: More disk space

### Why not auto-spawn agents on queue depth?
- Cost control (avoid runaway API usage)
- Human oversight of agent spawning
- Allows manual review of task before starting
- Tradeoff: Less automation

## Future Enhancements

**Considered but not implemented:**
- Real-time WebSocket updates (added complexity)
- LLM-based automatic prompt refinement (costly, risky)
- Auto-conflict resolution (too risky)
- Multi-repo support (scope creep)
- Role-based access control (not MVP)
- Distributed locking (not needed at current scale)

**Good candidates for v4:**
- SQLite backend (keeps JSONL as export format)
- Web dashboard (readonly, generated from state)
- Metrics export to Prometheus
- Git hooks for validation
- Auto-archive of old evidence

