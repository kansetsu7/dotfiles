---
triggers:
- /amend
---

Amend staged changes to the previous commit and update the commit message.

## Arguments

- `$ARGUMENTS`: Optional flags
  - `--force` or `-f`: Skip the "not pushed" check (allows amending commits that will need force push)
  - Example: `/amend --force`

## Safety Checks (MUST pass before amending)

1. **Check authorship**: `git log -1 --format='%an %ae'`
   - STOP if author is not the current user

2. **Check not pushed** (skip if `--force` flag provided): `git status`
   - Must show "Your branch is ahead of..." or "nothing to commit"
   - STOP if commit is already on remote (unless `--force`)
   - Warn user if skipping: "Warning: This commit may need force push after amending"

3. **Check has changes**: `git diff --cached --stat`
   - STOP if no staged changes (nothing to amend)

## Workflow

1. Run safety checks above
2. Show current commit message: `git log -1 --format='%B'`
3. Show staged changes: `git diff --cached`
4. Ask user to confirm or edit the commit message
5. Run: `git commit --amend -m "<updated message>"`
6. Verify: `git log -1`
7. If `--force` was used, remind user: "Run `git push --force-with-lease` to update remote"

## Error Messages

- **Wrong author**: "Cannot amend: commit authored by <name>, not you"
- **Already pushed**: "Cannot amend: commit already pushed to remote. Use `/amend --force` to override"
- **No changes**: "Nothing to amend: no staged changes found"
