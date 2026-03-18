#!/usr/bin/env bash
# scram-init.sh — Create workspace directory structure and write session manifest skeleton.
# Usage: scram-init.sh [--nano] <workspace-path>
# Exit 0: success
# Exit 1: directory creation or session.md write failed

set -euo pipefail

NANO=false
if [ "${1:-}" = "--nano" ]; then
  NANO=true
  shift
fi

if [ $# -lt 1 ]; then
  echo "Usage: scram-init.sh [--nano] <workspace-path>" >&2
  exit 1
fi

WORKSPACE_PATH="$1"

# Create workspace directories
if [ "$NANO" = "true" ]; then
  if ! mkdir -p "$WORKSPACE_PATH/events"; then
    echo "Error: failed to create workspace directories at $WORKSPACE_PATH" >&2
    exit 1
  fi
else
  if ! mkdir -p "$WORKSPACE_PATH/briefs" "$WORKSPACE_PATH/retro" "$WORKSPACE_PATH/events"; then
    echo "Error: failed to create workspace directories at $WORKSPACE_PATH" >&2
    exit 1
  fi
fi

# Write session.md skeleton with current UTC timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$WORKSPACE_PATH/session.md" << EOF
---
feature_name: ""
integration_branch: ""
current_gate: ""
status: ""
retro: ""
created: $TIMESTAMP
updated: $TIMESTAMP
---

## Notes

EOF

if [ $? -ne 0 ]; then
  echo "Error: failed to write session.md at $WORKSPACE_PATH" >&2
  exit 1
fi

echo "SCRAM_WORKSPACE: $WORKSPACE_PATH"
exit 0
