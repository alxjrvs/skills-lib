#!/usr/bin/env bash
set -euo pipefail
# scram-backlog.sh — story state tracking for SCRAM backlogs.
# Usage:
#   scram-backlog.sh status <workspace> <story-slug>
#   scram-backlog.sh transition <workspace> <story-slug> <new-status>
#   scram-backlog.sh dispatchable <workspace>
#   scram-backlog.sh blocked <workspace>

# ---------------------------------------------------------------------------
# Valid transitions (from -> to)
# ---------------------------------------------------------------------------
is_valid_transition() {
  local from="$1" to="$2"
  case "${from}:${to}" in
    pending:in_progress) return 0 ;;
    in_progress:in_review) return 0 ;;
    in_review:merged) return 0 ;;
    in_review:failed) return 0 ;;
    failed:escalated) return 0 ;;
    escalated:in_progress) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Parse a backlog row: extract fields by pipe-delimited position.
# Pipe positions: |#|Story|Priority|Complexity|Resolution|Depends On|UI/UX|Status|Agent|Commit|
# Fields (1-indexed after split): 2=#, 3=Story, 4=Priority, 5=Complexity,
#   6=Resolution, 7=Depends On, 8=UI/UX, 9=Status, 10=Agent, 11=Commit
# ---------------------------------------------------------------------------
get_field() {
  # $1 = line, $2 = field number (pipe-delimited, 1-indexed)
  echo "$1" | awk -F'|' -v n="$2" '{gsub(/^[ \t]+|[ \t]+$/, "", $n); print $n}'
}

# ---------------------------------------------------------------------------
# Get backlog file path
# ---------------------------------------------------------------------------
backlog_file() {
  echo "$1/backlog.md"
}

# ---------------------------------------------------------------------------
# Find the row for a story slug. Prints the full line or nothing.
# ---------------------------------------------------------------------------
find_story_row() {
  local ws="$1" slug="$2"
  grep -E "^\|[^|]*\|[[:space:]]*${slug}[[:space:]]*\|" "$(backlog_file "$ws")" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# cmd: status <workspace> <story-slug>
# ---------------------------------------------------------------------------
cmd_status() {
  local ws="$1" slug="$2"
  local row
  row=$(find_story_row "$ws" "$slug")
  if [ -z "$row" ]; then
    echo "error: story '$slug' not found" >&2
    exit 1
  fi
  # Status is field 9 (pipe-delimited, 1-indexed including leading empty)
  get_field "$row" 9
}

# ---------------------------------------------------------------------------
# cmd: transition <workspace> <story-slug> <new-status>
# ---------------------------------------------------------------------------
cmd_transition() {
  local ws="$1" slug="$2" new_status="$3"
  local row current_status
  row=$(find_story_row "$ws" "$slug")
  if [ -z "$row" ]; then
    echo "error: story '$slug' not found" >&2
    exit 1
  fi

  current_status=$(get_field "$row" 9)

  if ! is_valid_transition "$current_status" "$new_status"; then
    echo "error: invalid transition $current_status -> $new_status" >&2
    exit 1
  fi

  # Update the status in backlog.md using sed.
  # Replace the status field in the matching row.
  local bf
  bf=$(backlog_file "$ws")
  # Use sed to find the line with this slug and replace the status field.
  # We match on the slug and replace the 8th pipe-delimited content field (9th awk field).
  sed -i '' "s/^\(|[^|]*|[[:space:]]*${slug}[[:space:]]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|\)[[:space:]]*${current_status}[[:space:]]*\(|.*\)/\1 ${new_status} \2/" "$bf"

  # On merged: check for type contracts in brief
  if [ "$new_status" = "merged" ]; then
    local brief="$ws/briefs/${slug}.md"
    if [ -f "$brief" ] && grep -q "^## Type Contracts" "$brief"; then
      mkdir -p "$ws/retro"
      echo "- [type-drift] ${slug}: has Type Contracts — verify conformance" >> "$ws/retro/in-flight.md"
    fi
  fi
}

# ---------------------------------------------------------------------------
# cmd: dispatchable <workspace>
# Print story slugs that are pending, have all deps merged (or no deps),
# no HALT file, and .scram-state contains "streams".
# ---------------------------------------------------------------------------
cmd_dispatchable() {
  local ws="$1"

  # Guard: HALT file
  if [ -f "$ws/HALT" ]; then
    return 0
  fi

  # Guard: .scram-state must contain "streams"
  if [ ! -f "$ws/.scram-state" ] || ! grep -q "streams" "$ws/.scram-state"; then
    return 0
  fi

  local bf
  bf=$(backlog_file "$ws")

  # Read each data row (skip header and separator)
  while IFS= read -r line; do
    # Skip non-data rows
    echo "$line" | grep -qE '^\|[[:space:]]*[0-9]' || continue

    local slug status deps
    slug=$(get_field "$line" 3)
    status=$(get_field "$line" 9)
    deps=$(get_field "$line" 7)

    # Only pending stories
    [ "$status" = "pending" ] || continue

    # Check deps
    if [ "$deps" = "—" ] || [ -z "$deps" ]; then
      echo "$slug"
      continue
    fi

    # Check each dep is merged
    local all_merged=true
    local IFS_SAVE="$IFS"
    IFS=','
    for dep_num in $deps; do
      dep_num=$(echo "$dep_num" | tr -d ' ')
      # Find the row for this dep number
      local dep_row
      dep_row=$(grep -E "^\|[[:space:]]*${dep_num}[[:space:]]*\|" "$bf" 2>/dev/null || true)
      if [ -n "$dep_row" ]; then
        local dep_status
        dep_status=$(get_field "$dep_row" 9)
        if [ "$dep_status" != "merged" ]; then
          all_merged=false
          break
        fi
      fi
    done
    IFS="$IFS_SAVE"

    if $all_merged; then
      echo "$slug"
    fi
  done < "$bf"
}

# ---------------------------------------------------------------------------
# cmd: blocked <workspace>
# Print story slugs that are pending and have any dep not merged.
# ---------------------------------------------------------------------------
cmd_blocked() {
  local ws="$1"
  local bf
  bf=$(backlog_file "$ws")

  while IFS= read -r line; do
    echo "$line" | grep -qE '^\|[[:space:]]*[0-9]' || continue

    local slug status deps
    slug=$(get_field "$line" 3)
    status=$(get_field "$line" 9)
    deps=$(get_field "$line" 7)

    [ "$status" = "pending" ] || continue

    # No deps = not blocked
    if [ "$deps" = "—" ] || [ -z "$deps" ]; then
      continue
    fi

    # Check if any dep is not merged
    local IFS_SAVE="$IFS"
    IFS=','
    for dep_num in $deps; do
      dep_num=$(echo "$dep_num" | tr -d ' ')
      local dep_row
      dep_row=$(grep -E "^\|[[:space:]]*${dep_num}[[:space:]]*\|" "$bf" 2>/dev/null || true)
      if [ -n "$dep_row" ]; then
        local dep_status
        dep_status=$(get_field "$dep_row" 9)
        if [ "$dep_status" != "merged" ]; then
          echo "$slug"
          break
        fi
      fi
    done
    IFS="$IFS_SAVE"
  done < "$bf"
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
CMD="${1:-}"
shift || true

case "$CMD" in
  status)
    [ $# -ge 2 ] || { echo "usage: scram-backlog.sh status <workspace> <story-slug>" >&2; exit 1; }
    cmd_status "$1" "$2"
    ;;
  transition)
    [ $# -ge 3 ] || { echo "usage: scram-backlog.sh transition <workspace> <story-slug> <new-status>" >&2; exit 1; }
    cmd_transition "$1" "$2" "$3"
    ;;
  dispatchable)
    [ $# -ge 1 ] || { echo "usage: scram-backlog.sh dispatchable <workspace>" >&2; exit 1; }
    cmd_dispatchable "$1"
    ;;
  blocked)
    [ $# -ge 1 ] || { echo "usage: scram-backlog.sh blocked <workspace>" >&2; exit 1; }
    cmd_blocked "$1"
    ;;
  *)
    echo "usage: scram-backlog.sh {status|transition|dispatchable|blocked} ..." >&2
    exit 1
    ;;
esac
