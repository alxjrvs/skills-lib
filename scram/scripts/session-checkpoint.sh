#!/usr/bin/env bash
# session-checkpoint.sh — Write a last-seen timestamp to an active SCRAM session manifest.
# Registered as a Stop hook. Always exits 0.

# No-op if SCRAM_WORKSPACE is unset or empty
if [ -z "${SCRAM_WORKSPACE:-}" ]; then
  exit 0
fi

SESSION_FILE="$SCRAM_WORKSPACE/session.md"

# No-op if session.md does not exist
if [ ! -f "$SESSION_FILE" ]; then
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update the updated: line in YAML frontmatter
if grep -q '^updated:' "$SESSION_FILE"; then
  # Replace existing updated: line
  sed -i.bak "s|^updated:.*$|updated: $TIMESTAMP|" "$SESSION_FILE"
  rm -f "$SESSION_FILE.bak"
else
  # No updated: line exists — append before closing ---
  # Find the line number of the closing --- (second occurrence)
  CLOSE_LINE=$(grep -n '^---$' "$SESSION_FILE" | sed -n '2p' | cut -d: -f1)
  if [ -n "$CLOSE_LINE" ]; then
    sed -i.bak "${CLOSE_LINE}i\\
updated: $TIMESTAMP" "$SESSION_FILE"
    rm -f "$SESSION_FILE.bak"
  fi
fi

exit 0
