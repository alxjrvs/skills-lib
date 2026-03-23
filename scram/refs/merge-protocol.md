# Merge Protocol

## Pre-Merge Checks

Before merging any story, verify:

1. Approval records exist in `SCRAM_WORKSPACE/session.md` under `## Approvals`
   - Simple stories: single maintainer approval sufficient
   - Moderate/complex stories: both maintainers must independently approve
2. The merge is **gated** on approval records existing — do not begin until they are written

## Merge Procedure (atomic, per-story)

1. Copy files from worktree to integration branch
2. Stage specific files — **never use `git add -A`**
3. Commit with conventional commit format + `Co-Authored-By` (see `refs/commit-format.md`)
4. **Run the full test suite** after the merge to verify integration branch health
5. Verify commit succeeded — check `git log`
6. Remove the worktree (`git worktree remove`)

## One Atomic Commit Per Story

Do not batch. Do not wait. First done, first merged.

Never bundle multiple stories into a single commit, even if they touch overlapping files. Each story produces exactly one atomic commit.

## If Tests Fail After Merge

Revert the merge immediately. Return the story to the backlog with failure details and redispatch. Do NOT proceed with further merges until the integration branch is green.

## Conflict Resolution

- **Trivial conflicts** (import ordering, adjacent edits): resolve directly in the integration branch
- **Substantive conflicts** (competing logic changes): pause the conflicting story. Merge all non-conflicting work first. Redispatch the story against the updated integration branch with a fresh context brief.

## Tracker Updates (if configured)

If the user provided an external tracker during G0:

- **After each merge:** Update the corresponding issue — add a comment with the commit hash, mark as "Done" / "Merged" / equivalent status
- **On revert:** Update the issue back to "In Progress" with details on what broke
- **If tracker API fails:** Log what you would have updated and continue. Report missed updates to the user at the end.

Use available tools (`gh` CLI, MCP tools) for tracker operations. If tools are unavailable, log the update and report missed updates to the user at the end.

## Git Safety Rules

- **NEVER** use `LEFTHOOK=0`, `--no-verify`, or `--no-gpg-sign`
- **NEVER** amend existing commits — always create new commits
- **NEVER** force push
- **NEVER** merge further stories while the integration branch has failing tests
- If hooks fail, investigate the root cause and fix it
- If pre-existing issues block commits, report to the user
