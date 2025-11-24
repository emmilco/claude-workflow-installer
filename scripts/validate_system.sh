#!/usr/bin/env bash
# System validation script - checks that workflow is properly set up

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "=========================================="
echo "Multi-Agent Workflow - System Validation"
echo "=========================================="
echo ""

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

# Check if in git repository
echo "Checking git repository..."
if [ -d ".git" ]; then
    check_pass "In git repository"
else
    check_fail "Not in a git repository"
fi

# Check git version
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    GIT_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
    GIT_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)

    if [ "$GIT_MAJOR" -gt 2 ] || ([ "$GIT_MAJOR" -eq 2 ] && [ "$GIT_MINOR" -ge 25 ]); then
        check_pass "Git version $GIT_VERSION (>= 2.25)"
    else
        check_fail "Git version $GIT_VERSION (need >= 2.25 for worktree support)"
    fi
else
    check_fail "Git not installed"
fi

# Check Python
echo ""
echo "Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    check_pass "Python $PYTHON_VERSION installed"
else
    check_fail "Python3 not installed"
fi

# Check jq
echo ""
echo "Checking jq..."
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version 2>&1)
    check_pass "jq installed ($JQ_VERSION)"
else
    check_fail "jq not installed (required for spawn_agent.sh)"
    echo "  Install: brew install jq (macOS) or apt-get install jq (Ubuntu)"
fi

# Check workflow structure
echo ""
echo "Checking workflow structure..."

if [ -d ".workflow" ]; then
    check_pass ".workflow/ directory exists"
else
    check_fail ".workflow/ directory missing"
fi

required_dirs=(
    ".workflow/scripts/core"
    ".workflow/scripts/worktree"
    ".workflow/scripts/evolution"
    ".workflow/prompts"
    ".workflow/hooks"
    ".workflow/templates"
    "worktrees"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        check_pass "$dir exists"
    else
        check_fail "$dir missing"
    fi
done

# Check required scripts
echo ""
echo "Checking scripts..."

required_scripts=(
    ".workflow/scripts/core/task_manager.py"
    ".workflow/scripts/worktree/spawn_agent.sh"
    ".workflow/scripts/worktree/submit_for_review.sh"
    ".workflow/scripts/worktree/spawn_reviewer.sh"
    ".workflow/scripts/worktree/complete_review.sh"
    ".workflow/scripts/evolution/self_healing_monitor.py"
    ".workflow/scripts/evolution/evolve_prompts.py"
)

for script in "${required_scripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            check_pass "$script exists and is executable"
        else
            check_warn "$script exists but is not executable"
            echo "  Run: chmod +x $script"
        fi
    else
        check_fail "$script missing"
    fi
done

# Check required prompts
echo ""
echo "Checking prompts..."

required_prompts=(
    ".workflow/prompts/architect.md"
    ".workflow/prompts/implementer.md"
    ".workflow/prompts/reviewer.md"
    ".workflow/prompts/integrator.md"
    ".workflow/prompts/tester.md"
    ".workflow/prompts/monitor.md"
)

for prompt in "${required_prompts[@]}"; do
    if [ -f "$prompt" ]; then
        check_pass "$prompt exists"
    else
        check_fail "$prompt missing"
    fi
done

# Check state files
echo ""
echo "Checking state files..."

if [ -f "TASKS.jsonl" ]; then
    check_pass "TASKS.jsonl exists"

    # Check if it's valid JSONL
    if python3 -c "
import json
import sys
try:
    with open('TASKS.jsonl') as f:
        for line in f:
            if line.strip():
                json.loads(line)
    sys.exit(0)
except json.JSONDecodeError:
    sys.exit(1)
" 2>/dev/null; then
        check_pass "TASKS.jsonl is valid JSON"
    else
        check_fail "TASKS.jsonl contains invalid JSON"
    fi

    # Count tasks
    TASK_COUNT=$(wc -l < TASKS.jsonl | tr -d ' ')
    echo "  Tasks: $TASK_COUNT"
else
    check_fail "TASKS.jsonl missing"
fi

if [ -f "IN_PROGRESS.md" ]; then
    check_pass "IN_PROGRESS.md exists"
else
    check_warn "IN_PROGRESS.md missing (will be created on first task claim)"
fi

# Check .gitignore
echo ""
echo "Checking .gitignore..."

if [ -f ".gitignore" ]; then
    if grep -q "TASKS.jsonl" .gitignore && \
       grep -q "worktrees/" .gitignore && \
       grep -q ".tasks.lock" .gitignore; then
        check_pass ".gitignore configured correctly"
    else
        check_warn ".gitignore missing workflow entries"
        echo "  Should exclude: TASKS.jsonl, worktrees/, .tasks.lock, .workflow/evidence/, .workflow/monitoring/"
    fi
else
    check_warn ".gitignore missing"
fi

# Check for orphaned worktrees
echo ""
echo "Checking for issues..."

if [ -d "worktrees" ]; then
    WORKTREE_COUNT=$(ls -1 worktrees/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$WORKTREE_COUNT" -gt 0 ]; then
        echo "  Active worktrees: $WORKTREE_COUNT"

        # Check for orphans
        if [ -f "IN_PROGRESS.md" ]; then
            for dir in worktrees/*/; do
                if [ -d "$dir" ]; then
                    task_id=$(basename "$dir")
                    if ! grep -q "$task_id" IN_PROGRESS.md; then
                        check_warn "Orphaned worktree: $task_id"
                        echo "  Run: git worktree remove worktrees/$task_id"
                    fi
                fi
            done
        fi
    else
        echo "  No active worktrees"
    fi
fi

# Check for stale lock files
if [ -f ".tasks.lock" ]; then
    # Check if any process has it open
    if lsof .tasks.lock &>/dev/null; then
        check_warn "Lock file is currently held by a process"
    else
        check_warn "Stale lock file exists"
        echo "  Run: rm .tasks.lock"
    fi
fi

# Test task_manager.py import
echo ""
echo "Testing task_manager.py..."
if python3 -c "
import sys
sys.path.insert(0, '.workflow/scripts/core')
try:
    from task_manager import TaskManager
    tm = TaskManager()
    print('✓ task_manager.py loads successfully')
except Exception as e:
    print(f'✗ task_manager.py failed to load: {e}')
    sys.exit(1)
" 2>&1; then
    check_pass "task_manager.py loads successfully"
else
    check_fail "task_manager.py failed to load"
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "Your workflow system is properly set up and ready to use."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warning(s)${NC}"
    echo ""
    echo "System is functional but has some non-critical issues."
    echo "Review warnings above for improvements."
    exit 0
else
    echo -e "${RED}$ERRORS error(s)${NC}, ${YELLOW}$WARNINGS warning(s)${NC}"
    echo ""
    echo "System is not properly set up. Fix errors above before using."
    echo ""
    echo "To set up the workflow, run:"
    echo "  bash scripts/setup_project.sh"
    exit 1
fi
