# Examples and Walkthroughs

This document provides concrete examples of using the multi-agent workflow system.

## Example 1: Complete Task Workflow

### Step-by-step walkthrough with actual data

**Initial state:**
```bash
$ cat TASKS.jsonl
# (empty file)

$ cat IN_PROGRESS.md
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
```

### 1. Create a task

```bash
$ python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Add user authentication" \
  --description "Implement JWT-based authentication for API endpoints" \
  --role "implementer" \
  --priority "high"

Created task: TASK-20251123-0042
```

**TASKS.jsonl now contains:**
```json
{"task_id": "TASK-20251123-0042", "title": "Add user authentication", "description": "Implement JWT-based authentication for API endpoints", "role": "implementer", "status": "available", "priority": "high", "files_in_scope": ["**/*"], "acceptance_criteria": ["unit_tests pass", "integration_smoke pass", "reviewer approval"], "created_at": "2025-11-23T10:30:15.234567Z", "claimed_by": null, "claimed_at": null, "completed_at": null, "worktree_path": null}
```

### 2. Spawn an implementer agent

```bash
$ bash .workflow/scripts/worktree/spawn_agent.sh implementer

===================================
Spawning implementer Agent
Agent ID: implementer-1732363815-12345
===================================

Finding next available task for role: implementer...
Selected task: TASK-20251123-0042 - Add user authentication

Claiming task...
✓ Task claimed
✓ Worktree created: worktrees/TASK-20251123-0042

===================================
Agent Ready
===================================

Next steps:

1. Change to worktree:
   cd worktrees/TASK-20251123-0042

2. View your task:
   cat .workflow/CURRENT_TASK.yaml

3. Start working on the task

4. When complete, create evidence and signal for review:
   bash .workflow/scripts/worktree/submit_for_review.sh TASK-20251123-0042
```

**TASKS.jsonl updated:**
```json
{"task_id": "TASK-20251123-0042", "title": "Add user authentication", "description": "Implement JWT-based authentication for API endpoints", "role": "implementer", "status": "claimed", "priority": "high", "files_in_scope": ["**/*"], "acceptance_criteria": ["unit_tests pass", "integration_smoke pass", "reviewer approval"], "created_at": "2025-11-23T10:30:15.234567Z", "claimed_by": "implementer-1732363815-12345", "claimed_at": "2025-11-23T10:32:45.123456Z", "completed_at": null, "worktree_path": "worktrees/TASK-20251123-0042"}
```

**IN_PROGRESS.md updated:**
```markdown
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
| TASK-20251123-0042 | implementer-1732363815-12345 | implementer | 2025-11-23T10:32:45.123456Z | worktrees/TASK-20251123-0042 | in_progress |
```

### 3. Work in the worktree

```bash
$ cd worktrees/TASK-20251123-0042

$ cat .workflow/CURRENT_TASK.yaml
task_id: TASK-20251123-0042
title: Add user authentication
description: |
  Implement JWT-based authentication for API endpoints

agent_id: implementer-1732363815-12345
role: implementer
claimed_at: 2025-11-23T10:32:45Z

acceptance_criteria:
  - unit_tests pass
  - integration_smoke pass
  - reviewer approval

instructions: |
  Work in this worktree (TASK-20251123-0042) to implement the task.

  When done:
  1. Run tests and capture evidence
  2. Create a claim with evidence file
  3. Signal ready for review

  Do NOT merge to main yourself - the Reviewer will handle that.

# Implement the feature
$ mkdir -p src/auth
$ cat > src/auth/jwt.py <<'EOF'
import jwt
import datetime

SECRET_KEY = "dev-secret-key"

def create_token(user_id: str) -> str:
    payload = {
        'user_id': user_id,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')

def verify_token(token: str) -> dict:
    return jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
EOF

# Write tests
$ mkdir -p tests
$ cat > tests/test_jwt.py <<'EOF'
import pytest
from src.auth.jwt import create_token, verify_token

def test_create_token():
    token = create_token("user123")
    assert isinstance(token, str)
    assert len(token) > 0

def test_verify_token():
    token = create_token("user123")
    payload = verify_token(token)
    assert payload['user_id'] == "user123"
EOF

# Run tests with fixed seed
$ pytest tests/test_jwt.py --randomly-seed=42
============================= test session starts ==============================
collected 2 items

tests/test_jwt.py ..                                                    [100%]

============================== 2 passed in 0.05s ===============================

# Commit changes
$ git add .
$ git commit -m "Implement JWT authentication

- Add JWT token creation and verification
- Add comprehensive tests
- All tests passing with seed 42"
[task/TASK-20251123-0042 abc1234] Implement JWT authentication
 2 files changed, 42 insertions(+)
 create mode 100644 src/auth/jwt.py
 create mode 100644 tests/test_jwt.py
```

### 4. Submit for review

```bash
$ bash .workflow/scripts/worktree/submit_for_review.sh TASK-20251123-0042

===================================
Submitting TASK-20251123-0042 for Review
===================================

Capturing evidence...
✓ Git status saved
✓ Changes diff saved
✓ Running tests...

pytest tests/test_jwt.py --randomly-seed=42
✓ Tests passed (2 passed)

Creating evidence package...
✓ Evidence package created at: ../../.workflow/evidence/TASK-20251123-0042/

Implementer claim created:
  Claim ID: TASK-20251123-0042-claim-1732364520
  Evidence hash: sha256:def456...
  Tests: 2 passed, 0 failed

✓ Task ready for review!

Next step: Have reviewer run:
  bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-20251123-0042
```

**Evidence created:**
```bash
$ ls -la .workflow/evidence/TASK-20251123-0042/
total 32
drwxr-xr-x  6 user  staff   192 Nov 23 10:45 .
drwxr-xr-x  3 user  staff    96 Nov 23 10:45 ..
-rw-r--r--  1 user  staff  1234 Nov 23 10:45 changes.diff
-rw-r--r--  1 user  staff   456 Nov 23 10:45 git_status.txt
-rw-r--r--  1 user  staff   890 Nov 23 10:45 implementer_claim.json
-rw-r--r--  1 user  staff  2345 Nov 23 10:45 test_output.txt
```

**implementer_claim.json:**
```json
{
  "claim_id": "TASK-20251123-0042-claim-1732364520",
  "task_id": "TASK-20251123-0042",
  "agent_id": "implementer-1732363815-12345",
  "role": "implementer",
  "timestamp": "2025-11-23T10:45:20.123456Z",
  "summary": "Implemented JWT authentication with token creation and verification",
  "files_modified": [
    "src/auth/jwt.py",
    "tests/test_jwt.py"
  ],
  "test_command": "pytest tests/test_jwt.py --randomly-seed=42",
  "test_seed": 42,
  "test_results": {
    "tests_run": 2,
    "tests_passed": 2,
    "tests_failed": 0,
    "duration_seconds": 0.05
  },
  "evidence_files": [
    "git_status.txt",
    "changes.diff",
    "test_output.txt"
  ],
  "evidence_hash": "sha256:def4567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "confidence": 0.95,
  "notes": "All tests passing with fixed seed. JWT implementation follows best practices."
}
```

### 5. Reviewer examines the code

```bash
$ cd ../../  # Back to main repo
$ bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-20251123-0042

===================================
Spawning Reviewer for TASK-20251123-0042
===================================

Loading evidence...
✓ Found implementer claim
✓ Evidence package loaded

Task: Add user authentication
Implementer: implementer-1732363815-12345
Files changed: 2
Tests: 2 passed, 0 failed

Evidence location: .workflow/evidence/TASK-20251123-0042/

Review checklist:
1. Code quality and style
2. Test coverage and quality
3. Security considerations
4. Performance implications
5. Documentation

To complete review:
  bash .workflow/scripts/worktree/complete_review.sh TASK-20251123-0042 [approved|rejected] "review notes"

# Reviewer examines evidence
$ cat .workflow/evidence/TASK-20251123-0042/changes.diff
# (shows the diff)

$ cat .workflow/evidence/TASK-20251123-0042/test_output.txt
# (shows test results)

# Reviewer checks out the code
$ cd worktrees/TASK-20251123-0042
$ cat src/auth/jwt.py
# (reviews implementation)

# Reviewer re-runs tests
$ pytest tests/test_jwt.py --randomly-seed=42
============================== 2 passed in 0.05s ===============================

# Reviewer approves
$ cd ../../
$ bash .workflow/scripts/worktree/complete_review.sh TASK-20251123-0042 approved \
  "Clean implementation with good test coverage. JWT handling follows best practices. Approved for merge."
```

**Review report created:**
```json
{
  "review_id": "TASK-20251123-0042-review-1732365120",
  "task_id": "TASK-20251123-0042",
  "reviewer_id": "reviewer-1732365120-67890",
  "timestamp": "2025-11-23T10:52:00.123456Z",
  "verdict": "approved",
  "confidence": 0.90,
  "issues": [],
  "suggestions": [
    "Consider adding token refresh mechanism in future iteration",
    "Document SECRET_KEY configuration for production"
  ],
  "alternatives": [],
  "security_concerns": [
    "SECRET_KEY should be moved to environment variable for production"
  ],
  "performance_notes": ["JWT operations are fast, no concerns"],
  "test_assessment": {
    "coverage": "good",
    "quality": "high",
    "gaps": ["Could add tests for expired tokens"]
  },
  "review_notes": "Clean implementation with good test coverage. JWT handling follows best practices. Approved for merge."
}
```

### 6. Merge and cleanup

```bash
===================================
Completing Review: TASK-20251123-0042
Verdict: approved
===================================

Merging to main...
✓ Merged task/TASK-20251123-0042 to main

Cleaning up worktree...
✓ Worktree removed

Updating task status...
✓ Task marked as completed

Task TASK-20251123-0042 is now completed and merged!
```

**Final TASKS.jsonl:**
```json
{"task_id": "TASK-20251123-0042", "title": "Add user authentication", "description": "Implement JWT-based authentication for API endpoints", "role": "implementer", "status": "completed", "priority": "high", "files_in_scope": ["**/*"], "acceptance_criteria": ["unit_tests pass", "integration_smoke pass", "reviewer approval"], "created_at": "2025-11-23T10:30:15.234567Z", "claimed_by": "implementer-1732363815-12345", "claimed_at": "2025-11-23T10:32:45.123456Z", "completed_at": "2025-11-23T10:52:30.123456Z", "worktree_path": "worktrees/TASK-20251123-0042"}
```

**IN_PROGRESS.md now empty:**
```markdown
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
```

## Example 2: Rejected Task

Same setup, but reviewer rejects:

```bash
$ bash .workflow/scripts/worktree/complete_review.sh TASK-20251123-0042 rejected \
  "Tests are insufficient. Please add tests for:
  - Expired token handling
  - Invalid token format
  - Missing claims in payload"

===================================
Completing Review: TASK-20251123-0042
Verdict: rejected
===================================

Feedback: Tests are insufficient...

Keeping worktree for rework...
✓ Task returned to available
✓ Removed from IN_PROGRESS.md

Implementer can rework the task and resubmit.
```

**TASKS.jsonl updated:**
```json
{"task_id": "TASK-20251123-0042", ..., "status": "available", "claimed_by": null, "claimed_at": null, ...}
```

Implementer can now reclaim the task, make improvements, and resubmit.

## Example 3: Multiple Parallel Tasks

```bash
# Create 3 tasks
$ for i in 1 2 3; do
    python3 .workflow/scripts/core/task_manager.py create-task \
      --title "Feature $i" \
      --description "Implement feature $i" \
      --role "implementer"
done

# In 3 separate terminal windows:
# Terminal 1:
$ bash .workflow/scripts/worktree/spawn_agent.sh implementer
# Claims TASK-20251123-0043

# Terminal 2:
$ bash .workflow/scripts/worktree/spawn_agent.sh implementer
# Claims TASK-20251123-0044

# Terminal 3:
$ bash .workflow/scripts/worktree/spawn_agent.sh implementer
# Claims TASK-20251123-0045

# Check IN_PROGRESS.md
$ cat IN_PROGRESS.md
# In Progress Tasks

**Max Concurrent: 6**

| Task ID | Agent ID | Role | Claimed At | Worktree | Status |
|---------|----------|------|------------|----------|--------|
| TASK-20251123-0043 | implementer-1732366000-11111 | implementer | 2025-11-23T11:00:00Z | worktrees/TASK-20251123-0043 | in_progress |
| TASK-20251123-0044 | implementer-1732366010-22222 | implementer | 2025-11-23T11:00:10Z | worktrees/TASK-20251123-0044 | in_progress |
| TASK-20251123-0045 | implementer-1732366020-33333 | implementer | 2025-11-23T11:00:20Z | worktrees/TASK-20251123-0045 | in_progress |
```

## Example 4: Stale Task Recovery

```bash
# Task claimed but agent crashed
$ cat IN_PROGRESS.md
| TASK-20251123-0046 | implementer-1732360000-99999 | implementer | 2025-11-23T08:00:00Z | worktrees/TASK-20251123-0046 | in_progress |

# Run monitor after 2+ hours
$ python3 .workflow/scripts/evolution/self_healing_monitor.py

=== Self-Healing Monitor ===
Detecting stale tasks...
  Found 1 stale task: TASK-20251123-0046 (claimed 3.5 hours ago)
  Auto-releasing TASK-20251123-0046...
  ✓ Task released back to available

Detecting orphaned worktrees...
  Found 1 orphaned worktree: worktrees/TASK-20251123-0046
  Cleaning up...
  ✓ Worktree removed

Health score: 0.85 (Good)

# Task is now available again
$ python3 .workflow/scripts/core/task_manager.py list-tasks --status available
TASK-20251123-0046  available  Implement feature X  implementer  high
```

## Role Examples

### Integrator vs Tester - When to Use Which

**Use Integrator role when:**
- You need to independently verify implementer's test results
- You want to check test determinism
- You're validating the evidence hash matches
- Goal: Ensure implementer's claims are reproducible

**Example:**
```bash
$ bash .workflow/scripts/worktree/spawn_agent.sh integrator
# Gets task that was already implemented and reviewed
# Re-runs exact same test command from implementer_claim.json
# Compares results
# Reports any divergence
```

**Use Tester role when:**
- You need broader integration testing beyond unit tests
- You're doing E2E testing
- You're performance testing
- You're security testing
- Goal: Find issues the implementer might have missed

**Example:**
```bash
$ bash .workflow/scripts/worktree/spawn_agent.sh tester
# Gets completed feature
# Runs full integration test suite
# Runs E2E tests
# Runs security scans
# Reports any issues found
```

**Typical flow:**
1. Implementer: writes code + unit tests
2. Reviewer: reviews code quality
3. Integrator: verifies test reproducibility (optional)
4. Tester: runs comprehensive test suite (for critical features)
5. Merge to main

## Task Cards Directory

The `.workflow/task_cards/` directory is for **storing reusable task templates**:

```bash
# Create a template for a common task type
$ cat > .workflow/task_cards/add_api_endpoint.yaml <<'EOF'
title: "Add API endpoint: {{ENDPOINT_NAME}}"
description: |
  Add a new API endpoint for {{ENDPOINT_NAME}}.

  Requirements:
  - RESTful design
  - Input validation
  - Error handling
  - OpenAPI documentation
  - Unit tests
  - Integration tests

role: implementer
priority: medium
files_in_scope:
  - "src/api/**/*.py"
  - "tests/api/**/*.py"
acceptance_criteria:
  - Unit tests pass (>90% coverage)
  - Integration tests pass
  - OpenAPI spec updated
  - Reviewer approval
EOF

# Use the template to create actual tasks
$ python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Add API endpoint: /users" \
  --description "$(cat .workflow/task_cards/add_api_endpoint.yaml | sed 's/{{ENDPOINT_NAME}}/\/users/g')" \
  --role "implementer"
```

This is different from `.workflow/templates/` which contains **output format templates** (claim format, review format, etc.).

