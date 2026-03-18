#!/usr/bin/env bash
# merge-guard.sh — Intercept git merge/rebase commands when SCRAM_WORKSPACE is set.
# Registered as PreToolUse on Bash.
# Exit 0: command is allowed (not a merge, or SCRAM_WORKSPACE not set)
# Exit 1: merge command detected without pre-merge-check approval

# Guard: no-op outside a SCRAM session
if [ -z "${SCRAM_WORKSPACE:-}" ]; then
  exit 0
fi

# Read stdin JSON (PreToolUse hook input — contains "command" field)
STDIN_JSON=$(cat 2>/dev/null || true)

# Extract the command from stdin JSON
if command -v jq &>/dev/null; then
  BASH_CMD=$(echo "$STDIN_JSON" | jq -r '.command // empty' 2>/dev/null)
else
  BASH_CMD=$(echo "$STDIN_JSON" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
fi

if [ -z "${BASH_CMD:-}" ]; then
  # Cannot extract command — exit 0 (no-op)
  exit 0
fi

# Check if the command contains a merge operation
IS_MERGE=0
if echo "$BASH_CMD" | grep -qE '(^|[[:space:]|;])git[[:space:]]+merge([[:space:]]|$)'; then
  IS_MERGE=1
fi

if [ "$IS_MERGE" -eq 0 ]; then
  # Not a merge command — allow through
  exit 0
fi

# Merge command detected. Run pre-merge-check.sh if we can extract the branch args.
# The merge-guard does NOT silently pass merge commands without verification.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

# Extract branch name from the merge command (the argument after 'git merge')
MERGE_TARGET=$(echo "$BASH_CMD" | grep -oE 'git[[:space:]]+merge[[:space:]]+([^[:space:]|;&]+)' | sed 's/git[[:space:]]*merge[[:space:]]*//' | head -1)

if [ -z "${MERGE_TARGET:-}" ]; then
  echo "MERGE_GUARD: blocked — could not extract merge target from command" >&2
  echo "  command: $BASH_CMD" >&2
  echo "  reason: git merge commands in a SCRAM session require pre-merge-check.sh verification" >&2
  echo "  action: run pre-merge-check.sh <branch> <sha> <integration-branch> before merging" >&2
  exit 1
fi

# Attempt to run pre-merge-check.sh if available
if [ -n "$PLUGIN_ROOT" ] && [ -f "$PLUGIN_ROOT/scripts/pre-merge-check.sh" ]; then
  # Extract integration branch from session.md
  SESSION_FILE="$SCRAM_WORKSPACE/session.md"
  INTEGRATION_BRANCH=""
  if [ -f "$SESSION_FILE" ]; then
    INTEGRATION_BRANCH=$(grep -E '^integration_branch:' "$SESSION_FILE" | head -1 | sed 's/^integration_branch:[[:space:]]*//' | tr -d '\r')
  fi

  if [ -n "$INTEGRATION_BRANCH" ]; then
    # Get current SHA for the merge target
    MERGE_SHA=$(git rev-parse --verify "refs/heads/$MERGE_TARGET" 2>/dev/null || true)
    if [ -n "$MERGE_SHA" ]; then
      if "$PLUGIN_ROOT/scripts/pre-merge-check.sh" "$MERGE_TARGET" "$MERGE_SHA" "$INTEGRATION_BRANCH" 2>&1; then
        echo "MERGE_GUARD: pass — pre-merge-check passed for $MERGE_TARGET"
        exit 0
      else
        echo "MERGE_GUARD: blocked — pre-merge-check failed for $MERGE_TARGET" >&2
        exit 1
      fi
    fi
  fi
fi

# Fallback: block with explanation if we could not run pre-merge-check.sh
echo "MERGE_GUARD: blocked — git merge detected in SCRAM session" >&2
echo "  command: $BASH_CMD" >&2
echo "  merge_target: $MERGE_TARGET" >&2
echo "  reason: git merge commands in a SCRAM session require pre-merge-check.sh verification" >&2
echo "  action: run pre-merge-check.sh <branch> <sha> <integration-branch> before merging" >&2
exit 1
