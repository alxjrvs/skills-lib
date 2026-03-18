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

exit 0
