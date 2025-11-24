# Migration Guide

## Upgrading to v3.1 (Latest)

### What's New in v3.1

**Critical fixes:**
- Fixed path errors in SKILL.md and spawn_agent.sh
- Added file locking for atomic task claiming (prevents race conditions)
- Added automatic project root detection (works from worktrees)
- Added worktree cleanup on claim failure
- Added jq dependency check in install.sh
- Improved error handling throughout

**New documentation:**
- ARCHITECTURE.md - Technical internals
- TROUBLESHOOTING.md - Common issues and solutions
- TESTING_GUIDE.md - How to test the workflow system
- EXAMPLES.md - Concrete walkthroughs with sample data

**New scripts:**
- `scripts/setup_project.sh` - Automated project setup
- `scripts/validate_system.sh` - System health validation

**Improvements:**
- Clarified "agent spawning" terminology (it's workspace setup, not automation)
- Added cost warnings for parallel agents
- Redesigned SHA256 verification strategy
- Complete task state model documentation
- Security considerations documented

### Breaking Changes

**None** - v3.1 is fully backward compatible with v3.0

### Upgrade Steps

#### If you have v3.0 installed globally:

```bash
# 1. Backup your current installation
cp -r ~/.claude/skills/multi-agent-workflow ~/.claude/skills/multi-agent-workflow.v3.0.backup

# 2. Pull latest version
cd /path/to/workflow_installer
git pull origin main

# 3. Reinstall
bash install.sh

# 4. Verify
bash scripts/validate_system.sh
```

#### If you have v3.0 set up in a project:

```bash
# 1. Backup project state
git checkout -b workflow-backup
git add TASKS.jsonl IN_PROGRESS.md DECISIONS.md
git commit -m "Backup workflow state before v3.1 upgrade"
git checkout main

# 2. Backup .workflow directory
cp -r .workflow .workflow.v3.0.backup

# 3. Update .workflow from global installation
bash /path/to/workflow_installer/scripts/setup_project.sh

# 4. Restore state files
cp .workflow.v3.0.backup/../TASKS.jsonl .
cp .workflow.v3.0.backup/../IN_PROGRESS.md .

# 5. Add new .gitignore entries
cat >> .gitignore <<'EOF'
.tasks.lock
EOF

# 6. Validate
bash .workflow/scripts/validate_system.sh

# 7. Commit upgrade
git add .workflow .gitignore
git commit -m "Upgrade to multi-agent workflow v3.1

- Updated scripts with bug fixes
- Added new documentation
- Added validation scripts
- Backward compatible with v3.0"
```

### Post-Upgrade Checklist

- [ ] `bash scripts/validate_system.sh` passes
- [ ] Can create tasks
- [ ] Can claim tasks
- [ ] Existing worktrees still work
- [ ] IN_PROGRESS.md format still correct
- [ ] Health monitoring works
- [ ] No orphaned worktrees
- [ ] Documentation links work

### New Features to Explore

#### 1. Automated Project Setup

Instead of manual 20-step setup:
```bash
bash /path/to/workflow_installer/scripts/setup_project.sh
```

#### 2. System Validation

Check health anytime:
```bash
bash scripts/validate_system.sh
```

#### 3. Improved Project Root Detection

Scripts now work from anywhere in the project:
```bash
cd worktrees/TASK-XXX/src/deep/nested/dir
python3 ../../../../../../.workflow/scripts/core/task_manager.py list-tasks
# Works! Auto-finds project root
```

#### 4. Better Error Handling

Worktree cleanup on failure, clearer error messages, recovery procedures documented.

## Migrating from Other Systems

### From Manual Git Workflow

If you're currently using manual git branches:

**Before:**
```bash
git checkout -b feature/add-auth
# Make changes
git commit -am "Add auth"
git checkout main
git merge feature/add-auth
```

**After:**
```bash
python3 .workflow/scripts/core/task_manager.py create-task \
  --title "Add auth" \
  --description "..." \
  --role "implementer"

bash .workflow/scripts/worktree/spawn_agent.sh implementer
cd worktrees/TASK-XXX
# Make changes
bash .workflow/scripts/worktree/submit_for_review.sh TASK-XXX
cd ../../
bash .workflow/scripts/worktree/complete_review.sh TASK-XXX approved "LGTM"
```

**Benefits:**
- Parallel work without branch switching
- Automatic task tracking
- Evidence collection
- Review workflow
- Self-healing

### From GitHub Issues

Import issues as tasks:
```bash
# Get issues from GitHub
gh issue list --json number,title,body,labels --limit 50 > issues.json

# Convert to tasks
python3 - <<'EOF'
import json

with open('issues.json') as f:
    issues = json.load(f)

for issue in issues:
    # Map labels to roles
    role = "implementer"
    if "bug" in [l for l in issue.get('labels', [])]:
        role = "implementer"
    elif "documentation" in [l for l in issue.get('labels', [])]:
        role = "implementer"  # or create "documenter" role

    title = issue['title']
    description = issue['body'] or "See GitHub issue #" + str(issue['number'])

    # Create task
    import subprocess
    subprocess.run([
        'python3', '.workflow/scripts/core/task_manager.py', 'create-task',
        '--title', title,
        '--description', description,
        '--role', role
    ])

print("✓ Imported GitHub issues as tasks")
EOF
```

### From Jira

Similar approach:
```bash
# Export Jira issues to CSV
# Parse and create tasks
python3 parse_jira_csv.py > tasks.sh
bash tasks.sh
```

## Rollback to v3.0

If you need to rollback:

```bash
# 1. Stop all agents
# Check no processes are using .workflow
lsof .workflow

# 2. Restore from backup
rm -rf .workflow
mv .workflow.v3.0.backup .workflow

# 3. Restore global installation
rm -rf ~/.claude/skills/multi-agent-workflow
mv ~/.claude/skills/multi-agent-workflow.v3.0.backup ~/.claude/skills/multi-agent-workflow

# 4. State files are compatible, no changes needed to TASKS.jsonl
```

## Version History

### v3.1.0 (2025-11-23)

**Fixed:**
- Path errors in SKILL.md and spawn_agent.sh
- Race conditions in task claiming (added file locking)
- Worktree cleanup on failure
- Project root detection from worktrees

**Added:**
- ARCHITECTURE.md
- TROUBLESHOOTING.md
- TESTING_GUIDE.md
- EXAMPLES.md
- MIGRATION.md (this file)
- scripts/setup_project.sh
- scripts/validate_system.sh
- .gitignore for state files
- Comprehensive dependency checking
- Cost warnings in documentation
- Security considerations

**Improved:**
- Task state model documentation
- SHA256 verification strategy
- Agent spawning terminology
- Reviewer workflow documentation
- Installation documentation
- Error messages throughout

### v3.0.0 (2025-11-23)

**Initial release:**
- Git worktree isolation
- Task state management
- Evidence-based verification
- Self-healing monitor
- Prompt evolution
- Six specialized roles
- Comprehensive documentation

## FAQ

### Will my existing tasks work after upgrade?

Yes, TASKS.jsonl format is unchanged. All existing tasks remain valid.

### Do I need to recreate worktrees?

No, existing worktrees continue to work. New worktrees benefit from improved cleanup on failure.

### What about in-progress work?

IN_PROGRESS.md format is unchanged. Current work continues seamlessly.

### Are the new scripts required?

No, they're optional utilities. Core workflow functionality remains the same.

### Can I mix v3.0 and v3.1?

Yes, but it's recommended to upgrade completely. The file locking improvement in v3.1 prevents race conditions that v3.0 doesn't handle.

### What if upgrade fails?

Rollback using the backup you created. The system is designed to be resilient - state files are never modified during upgrade, only .workflow/ scripts are updated.

### How do I test the upgrade worked?

```bash
bash scripts/validate_system.sh
# Should pass all checks

# Try a simple workflow
python3 .workflow/scripts/core/task_manager.py create-task --title "Test" --description "Test" --role "implementer"
bash .workflow/scripts/worktree/spawn_agent.sh implementer
# Should work without errors
```

### Where can I get help?

1. Check TROUBLESHOOTING.md
2. Check ARCHITECTURE.md for design details
3. Run `bash scripts/validate_system.sh` for diagnostics
4. Check closed issues in the repository
5. Open a new issue with diagnostics

