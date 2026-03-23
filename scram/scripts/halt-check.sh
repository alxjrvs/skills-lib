#!/usr/bin/env bash
# halt-check.sh — Block agent dispatch when a HALT condition is active.
# Registered as PreToolUse on Agent.
# Exit 0: no HALT (dispatch may proceed)
# Exit 1: HALT active (dispatch is blocked)

if [ -z "${SCRAM_WORKSPACE:-}" ]; then
  exit 0
fi

HALT_FILE="$SCRAM_WORKSPACE/HALT"

if [ -f "$HALT_FILE" ]; then
  HALT_CONTENTS=$(cat "$HALT_FILE")
  echo "HALT: $HALT_CONTENTS" >&2
  exit 1
fi

# State gate check — only during sprint (SCRAM_WORKSPACE with .scram-state)
if [ -f "$SCRAM_WORKSPACE/.scram-state" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if ! "$SCRIPT_DIR/scram-state.sh" require "$SCRAM_WORKSPACE" streams 2>/dev/null; then
    echo "SCRAM state is not in 'streams' phase — agent dispatch blocked" >&2
    exit 1
  fi
fi

exit 0
