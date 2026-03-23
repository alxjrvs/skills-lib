#!/usr/bin/env bash
# isolation-check.sh — Verify worktree isolation after developer-impl agent dispatch.
# Registered as PostToolUse on Agent.
# Exit 0: isolation check passed or not applicable
# Exit 1: isolation failure detected (HALT written to SCRAM_WORKSPACE)

# ## Known Limitations
#
# PostToolUse on Agent fires after ANY agent completes — it cannot be scoped to
# only `scram:developer-impl` invocations in the current hooks API. The hook is
# registered with matcher "Agent" which matches all agent tool completions.
# This script guards against false positives by checking SCRAM_WORKSPACE before
# doing any meaningful work. When SCRAM_WORKSPACE is not set (e.g., non-SCRAM
# agent invocations), the script exits 0 immediately without any side effects.

# Guard: no-op outside a SCRAM session
if [ -z "${SCRAM_WORKSPACE:-}" ]; then
  exit 0
fi

# Read stdin JSON (PostToolUse hook input — may contain agent output)
STDIN_JSON=$(cat 2>/dev/null || true)

# Locate the most recently modified worktree (if any)
# Worktrees are stored under .claude/worktrees/ in the project root.
# We derive the project root from the git command run from SCRAM_WORKSPACE context.
# Since SCRAM_WORKSPACE is outside the repo, we resolve the project from session.md.
SESSION_FILE="$SCRAM_WORKSPACE/session.md"

if [ ! -f "$SESSION_FILE" ]; then
  # No session file — nothing to check
  exit 0
fi

# Extract project path from session.md frontmatter
PROJECT_PATH=$(grep -E '^project:' "$SESSION_FILE" | head -1 | sed 's/^project:[[:space:]]*//' | tr -d '\r')

if [ -z "${PROJECT_PATH:-}" ]; then
  # Cannot determine project path — exit 0 (no-op, not a failure)
  exit 0
fi

WORKTREES_DIR="$PROJECT_PATH/.claude/worktrees"

if [ ! -d "$WORKTREES_DIR" ]; then
  # No worktrees directory — nothing to check
  exit 0
fi

# Find the most recently created worktree directory
LATEST_WORKTREE=$(ls -td "$WORKTREES_DIR"/agent-* 2>/dev/null | head -1)

if [ -z "$LATEST_WORKTREE" ]; then
  # No worktrees found — nothing to check
  exit 0
fi

# Check isolation: verify the worktree is not on the integration branch itself.
# Read the current branch in that worktree.
WORKTREE_BRANCH=$(git -C "$LATEST_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

if [ -z "$WORKTREE_BRANCH" ]; then
  # Cannot read branch — exit 0 (not a failure we can detect)
  exit 0
fi

# Extract integration branch from session.md
INTEGRATION_BRANCH=$(grep -E '^integration_branch:' "$SESSION_FILE" | head -1 | sed 's/^integration_branch:[[:space:]]*//' | tr -d '\r')

if [ -z "${INTEGRATION_BRANCH:-}" ]; then
  # Cannot determine integration branch — exit 0
  exit 0
fi

# Isolation check: worktree must NOT be on the integration branch directly.
# A properly set up worktree should be on a story branch (a branch branched from the integration branch).
if [ "$WORKTREE_BRANCH" = "$INTEGRATION_BRANCH" ]; then
  echo "ISOLATION_CHECK: fail" >&2
  echo "  worktree: $LATEST_WORKTREE" >&2
  echo "  branch: $WORKTREE_BRANCH" >&2
  echo "  reason: worktree is on integration branch directly (not a story branch)" >&2

  # Write HALT file to signal orchestrator
  echo "Isolation failure in $LATEST_WORKTREE — worktree is on integration branch '$INTEGRATION_BRANCH' directly at $(date)" > "$SCRAM_WORKSPACE/HALT"
  exit 1
fi

echo "ISOLATION_CHECK: pass"
echo "  worktree: $LATEST_WORKTREE"
echo "  branch: $WORKTREE_BRANCH"

# Mark story as in_progress in backlog (sprint only)
if [ -n "${SCRAM_WORKSPACE:-}" ] && [ -f "$SCRAM_WORKSPACE/backlog.md" ] && [ -n "${STORY_SLUG:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  "$SCRIPT_DIR/scram-backlog.sh" transition "$SCRAM_WORKSPACE" "$STORY_SLUG" in_progress 2>/dev/null || true
fi

exit 0
