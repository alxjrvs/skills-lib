#!/usr/bin/env bash
# session-checkpoint.sh — Write a last-seen timestamp to an active SCRAM session manifest
# and append a checkpoint event to events/stream.log.
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

# Append checkpoint event to events/stream.log
EVENTS_DIR="$SCRAM_WORKSPACE/events"
mkdir -p "$EVENTS_DIR" 2>/dev/null || true
GATE=$(grep '^current_gate:' "$SESSION_FILE" 2>/dev/null | sed 's/^current_gate:[[:space:]]*//' | tr -d '"' | tr -d "'" | head -1)
echo "{\"ts\":\"$TIMESTAMP\",\"type\":\"checkpoint\",\"gate\":\"${GATE:-unknown}\"}" >> "$EVENTS_DIR/stream.log"

exit 0
