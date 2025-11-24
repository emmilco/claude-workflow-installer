# Multi-Agent Workflow v3 - Package Summary

## What This Package Provides

A complete, production-ready multi-agent workflow system designed for parallel software development with Claude Code agents. This package includes **all missing critical infrastructure** identified in the original ChatGPT skill.

## Key Improvements Over Original Skill

### ✅ Added: Git Worktree Management
**Original:** No worktree workflow
**Now:** Complete worktree lifecycle
- `spawn_agent.sh` - Automatically creates worktrees for tasks
- `submit_for_review.sh` - Packages evidence and commits
- `complete_review.sh` - Merges to main and cleans up
- Prevents file conflicts between parallel agents

### ✅ Added: Task Claiming/Locking Mechanism
**Original:** No claim mechanism
**Now:** Full state machine in `task_manager.py`
- Atomic task claiming with concurrency limits (default: 6)
- `IN_PROGRESS.md` for human-readable tracking
- Prevents double-claiming
- Status transitions: available → claimed → completed

### ✅ Added: Self-Healing Infrastructure
**Original:** No recovery mechanisms
**Now:** Automatic issue detection and remediation
- Stale task detection (>2 hours inactive)
- Orphaned worktree cleanup
- Auto-release of stuck tasks
- Health score computation
- Anomaly detection vs. historical baseline

### ✅ Added: Self-Updating Capability
**Original:** Static prompts
**Now:** Empirical prompt evolution
- Analyzes completed task outcomes
- Identifies common failure patterns by role
- Proposes specific prompt improvements
- Tracks prompt versions with archive
- Logs evolution decisions

### ✅ Added: Evidence Generation Logic
**Original:** Placeholder that redirected stdout to JSON
**Now:** Proper evidence capture
- Structured JSON evidence files
- Git diff, test output, status captured
- SHA256 hashing for verification
- Independent re-execution framework
- Divergence detection and reporting

### ✅ Added: Proper Merge Workflow
**Original:** Unclear how work gets to main
**Now:** Review-gated merging
- Work stays in worktree until approved
- Reviewer validates before merge
- Automatic merge with `--no-ff` for clean history
- Worktree cleanup post-merge
- No rollbacks needed (bad work never touches main)

### ✅ Added: Concurrency Control
**Original:** No limits on agent spawning
**Now:** Configurable limits with queueing
- Default: 6 concurrent tasks
- Queue depth tracking
- Utilization monitoring
- Auto-scaling recommendations

## Package Contents

### Core Scripts

1. **task_manager.py** (495 lines)
   - Full CRUD for tasks
   - Claim/release with worktree integration
   - Stale detection
   - Force release for recovery

2. **self_healing_monitor.py** (485 lines)
   - Health metric collection
   - Anomaly detection
   - Auto-remediation
   - Alert generation
   - Dashboard creation

3. **evolve_prompts.py** (425 lines)
   - Outcome analysis
   - Pattern detection
   - Improvement proposals
   - Auto-apply capabilities
   - Version tracking

### Worktree Scripts

4. **spawn_agent.sh**
   - Claims next available task for role
   - Creates git worktree
   - Loads role prompt
   - Creates task card in worktree

5. **submit_for_review.sh**
   - Captures evidence (diff, tests, status)
   - Runs test suite
   - Computes SHA256 hash
   - Creates implementer claim

6. **spawn_reviewer.sh**
   - Sets up review context
   - Packages evidence for examination
   - Provides review checklist

7. **complete_review.sh**
   - Merges to main (if approved)
   - Returns to available (if rejected)
   - Cleans up worktree
   - Updates task status

### Role Prompts

Comprehensive prompts for each role (~200-400 lines each):

8. **architect.md** - System design, task breakdown, decision logging
9. **implementer.md** - Coding standards, testing, evidence creation
10. **reviewer.md** - Review checklist, quality standards, feedback
11. **integrator.md** - Independent verification, divergence detection
12. **tester.md** - Integration/E2E testing, performance, security
13. **monitor.md** - Metrics, alerts, health tracking, improvements

### Hooks

14. **pre_tool_use.sh** - Prevents dangerous operations (force push, direct merge)
15. **stop_gate.sh** - Lightweight validation after responses

### Templates

16. **task_card.template.yaml** - Task specification format
17. **review_report.template.json** - Review output format
18. **decision_log.template.md** - Architecture decision format
19. **implementer_claim.template.json** - Evidence claim format

### Documentation

20. **README.md** - Complete usage guide with examples
21. **SKILL.md** - Claude Code skill with triggers and integration
22. **QUICK_START.md** - 10-minute getting started guide
23. **requirements.txt** - Optional Python dependencies

### Installation

24. **install.sh** - Automated setup for any git repository

## How It Addresses Your Requirements

### Requirement: "Agents should use a fresh git worktree for each task"
✅ **Implemented:** `spawn_agent.sh` automatically creates worktrees via `task_manager.py`

### Requirement: "Claim/lock task mechanism in TASKS file, limit to 6 tasks"
✅ **Implemented:** `task_manager.py` enforces `max_concurrent = 6` with atomic claiming

### Requirement: "No polling - use hooks for notifications"
✅ **Implemented:** Hooks trigger on PreToolUse and Stop events

### Requirement: "Don't merge until reviewer approves"
✅ **Implemented:** `complete_review.sh` only merges on 'approved' verdict

### Requirement: "Self-healing"
✅ **Implemented:** `self_healing_monitor.py` auto-remediates stale tasks, orphaned worktrees

### Requirement: "Self-updating"
✅ **Implemented:** `evolve_prompts.py` analyzes outcomes and proposes prompt improvements

## Installation & Usage

```bash
# Install into your project
cd /path/to/your/project
bash /path/to/workflow_v3/install.sh .

# Create first task
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Your task" \
  --description "Description" \
  --role "implementer"

# Spawn agent
bash .workflow/scripts/worktree/spawn_agent.sh implementer

# Work in worktree
cd worktrees/TASK-*
# ... make changes ...
bash .workflow/scripts/worktree/submit_for_review.sh TASK-*

# Review
cd ../../
bash .workflow/scripts/worktree/spawn_reviewer.sh TASK-*
bash .workflow/scripts/worktree/complete_review.sh TASK-* approved "LGTM"

# Monitor health
python3 .workflow/scripts/evolution/self_healing_monitor.py
```

## Technical Specifications

**Language:** Python 3.7+ (core), Bash (orchestration)
**Dependencies:** None required (stdlib only), optional testing/quality tools
**Git Version:** 2.25+ (for worktree support)
**Platform:** Linux, macOS (Windows with Git Bash)

**Lines of Code:**
- Python: ~1,400 lines
- Bash: ~600 lines
- Markdown (prompts/docs): ~4,500 lines
- **Total:** ~6,500 lines

## What Makes This Production-Ready

1. **Error Handling:** All scripts check for errors and provide clear messages
2. **Idempotency:** Operations can be safely retried
3. **Atomicity:** State changes are atomic (no partial updates)
4. **Observability:** Comprehensive logging and monitoring
5. **Documentation:** Inline comments + extensive markdown docs
6. **Portability:** Works in any git repo with minimal dependencies
7. **Extensibility:** Easy to add custom roles or metrics
8. **Safety:** Hooks prevent dangerous operations

## Testing Recommendations

Before production use:

1. **Test in a sandbox repo** - Try the full workflow with sample tasks
2. **Verify worktree isolation** - Run 2-3 agents in parallel
3. **Test failure scenarios** - Kill agents mid-task, verify auto-cleanup
4. **Validate evidence** - Check SHA256 verification catches changes
5. **Monitor for a week** - Ensure health metrics are meaningful

## Limitations & Future Enhancements

**Current Limitations:**
- Manual agent spawning (no auto-spawn based on queue depth)
- No built-in conflict resolution for merge conflicts
- Basic prompt evolution (could use LLM for sophisticated rewrites)
- No UI/dashboard (markdown only)

**Potential Enhancements:**
- Web dashboard for monitoring
- Auto-spawn agents when queue depth high
- LLM-based prompt refinement (using Anthropic API)
- Integration with Jira, GitHub Issues
- Prometheus/Grafana metrics export
- Slack/Discord alert integrations

## Support

- Read [README.md](README.md) for detailed usage
- Check [QUICK_START.md](QUICK_START.md) for fast setup
- Review role prompts in `prompts/` for behavior customization
- Examine templates in `templates/` for output formats

## Version

**v3.0.0** - Initial release with all critical infrastructure

---

**Built:** 2025-11-23
**Status:** Production-ready, portable, self-contained package
