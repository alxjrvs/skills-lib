#!/usr/bin/env bash
# scram-discover.sh — Find existing SCRAM sessions for the current project.
# Always exits 0 (even if no sessions found).

PROJECT_NAME=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || basename "$PWD")
SESSIONS=$(ls -d ~/.scram/"$PROJECT_NAME"--* 2>/dev/null)

if [ -z "$SESSIONS" ]; then
  echo "SCRAM_SESSIONS: none"
  exit 0
fi

echo "SCRAM_SESSIONS:"
INDEX=1
while IFS= read -r SESSION_DIR; do
  SESSION_FILE="$SESSION_DIR/session.md"
  CURRENT_GATE=""
  UPDATED=""

  if [ -f "$SESSION_FILE" ]; then
    CURRENT_GATE=$(grep '^current_gate:' "$SESSION_FILE" | cut -d' ' -f2-)
    UPDATED=$(grep '^updated:' "$SESSION_FILE" | cut -d' ' -f2-)
  fi

  echo "  $INDEX. $SESSION_DIR/ (gate: ${CURRENT_GATE:-unknown}, last updated: ${UPDATED:-unknown})"
  INDEX=$((INDEX + 1))
done <<< "$SESSIONS"

exit 0
