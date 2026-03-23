#!/usr/bin/env bash
set -euo pipefail

# scram-state.sh — Gate state machine for SCRAM sessions.
# Enforces valid sequential gate transitions mechanically.
#
# Usage:
#   scram-state.sh init <workspace>
#   scram-state.sh current <workspace>
#   scram-state.sh advance <workspace> <gate> [--skip]
#   scram-state.sh check <workspace> <gate>
#   scram-state.sh require <workspace> <gate>

GATES=(G0 G1 G2 G3 streams G4 G5 complete)

gate_index() {
  local target="$1"
  for i in "${!GATES[@]}"; do
    if [ "${GATES[$i]}" = "$target" ]; then
      echo "$i"
      return 0
    fi
  done
  echo "-1"
  return 1
}

cmd_init() {
  local workspace="$1"
  mkdir -p "$workspace/events"
  echo "G0" > "$workspace/.scram-state"
}

cmd_current() {
  local workspace="$1"
  cat "$workspace/.scram-state"
}

cmd_advance() {
  local workspace="$1"
  local target="$2"
  local skip="${3:-}"

  local current
  current=$(cat "$workspace/.scram-state")

  local current_idx
  current_idx=$(gate_index "$current")

  local target_idx
  target_idx=$(gate_index "$target") || {
    echo "error: invalid gate '$target'" >&2
    return 1
  }

  # The target must be exactly the next gate in sequence
  local expected_idx=$(( current_idx + 1 ))

  if [ "$expected_idx" -ge "${#GATES[@]}" ]; then
    echo "error: cannot advance past complete" >&2
    return 1
  fi

  if [ "$target_idx" -ne "$expected_idx" ]; then
    echo "error: invalid transition from $current to $target (expected ${GATES[$expected_idx]})" >&2
    return 1
  fi

  # Update state
  echo "$target" > "$workspace/.scram-state"

  # Log event
  local event_type="gate"
  if [ "$skip" = "--skip" ]; then
    event_type="gate_skip"
  fi

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"ts\":\"$ts\",\"type\":\"$event_type\",\"gate\":\"$target\"}" >> "$workspace/events/stream.log"
}

cmd_check() {
  local workspace="$1"
  local target="$2"

  local current
  current=$(cat "$workspace/.scram-state")

  local current_idx
  current_idx=$(gate_index "$current")

  local target_idx
  target_idx=$(gate_index "$target") || return 1

  if [ "$target_idx" -le "$current_idx" ]; then
    return 0
  else
    return 1
  fi
}

cmd_require() {
  local workspace="$1"
  local target="$2"

  local current
  current=$(cat "$workspace/.scram-state")

  if [ "$current" = "$target" ]; then
    return 0
  else
    return 1
  fi
}

# --- Main dispatch ---
ACTION="${1:-}"
shift || true

case "$ACTION" in
  init)    cmd_init "$@" ;;
  current) cmd_current "$@" ;;
  advance) cmd_advance "$@" ;;
  check)   cmd_check "$@" ;;
  require) cmd_require "$@" ;;
  *)
    echo "usage: scram-state.sh {init|current|advance|check|require} <workspace> [args]" >&2
    exit 1
    ;;
esac
