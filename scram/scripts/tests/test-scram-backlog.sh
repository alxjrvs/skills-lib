#!/usr/bin/env bash
# test-scram-backlog.sh — TDD tests for scram-backlog.sh.
# RED: these tests should fail before the script is created.
# GREEN: all tests pass after implementation.

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
ERRORS=""

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  - $1"
}

# Helper: create a temp workspace with sample backlog
setup_workspace() {
  local ws
  ws=$(mktemp -d)
  mkdir -p "$ws/retro"
  cat > "$ws/backlog.md" <<'BACKLOG'
# SCRAM Backlog — test

| # | Story | Priority | Complexity | Resolution | Depends On | UI/UX | Status | Agent | Commit |
|---|-------|----------|------------|------------|------------|-------|--------|-------|--------|
| 1 | story-a | P0 | simple | commit | — | no | pending | — | — |
| 2 | story-b | P1 | moderate | commit | 1 | no | pending | — | — |
| 3 | story-c | P2 | simple | commit | — | no | pending | — | — |
BACKLOG
  echo "streams" > "$ws/.scram-state"
  echo "$ws"
}

SCRIPT="$SCRIPTS_DIR/scram-backlog.sh"

# ---------------------------------------------------------------------------
# TEST GROUP 1: status — reads story status
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh status: reads story status ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  OUTPUT=$("$SCRIPT" status "$WS" "story-a" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ] && [ "$OUTPUT" = "pending" ]; then
    pass "status: returns 'pending' for story-a"
  else
    fail "status: expected 'pending' exit 0, got '$OUTPUT' exit $EXIT_CODE"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 2: status — non-existent story exits 1
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh status: non-existent story ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  OUTPUT=$("$SCRIPT" status "$WS" "no-such-story" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 1 ]; then
    pass "status: exits 1 for non-existent story"
  else
    fail "status: expected exit 1 for non-existent story, got $EXIT_CODE"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 3: transition — pending to in_progress succeeds
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh transition: pending -> in_progress ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  OUTPUT=$("$SCRIPT" transition "$WS" "story-a" "in_progress" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "transition: pending -> in_progress exits 0"
  else
    fail "transition: pending -> in_progress should exit 0, got $EXIT_CODE — $OUTPUT"
  fi

  # Verify file was updated
  NEW_STATUS=$("$SCRIPT" status "$WS" "story-a" 2>&1)
  if [ "$NEW_STATUS" = "in_progress" ]; then
    pass "transition: backlog.md updated to in_progress"
  else
    fail "transition: backlog.md not updated, status is '$NEW_STATUS'"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 4: transition — invalid (pending to merged) fails
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh transition: invalid pending -> merged ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  OUTPUT=$("$SCRIPT" transition "$WS" "story-a" "merged" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 1 ]; then
    pass "transition: pending -> merged exits 1 (invalid)"
  else
    fail "transition: pending -> merged should exit 1, got $EXIT_CODE"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 5: transition — in_review to failed succeeds
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh transition: in_review -> failed ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  # First move story-a through pending -> in_progress -> in_review
  "$SCRIPT" transition "$WS" "story-a" "in_progress" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "in_review" >/dev/null 2>&1
  OUTPUT=$("$SCRIPT" transition "$WS" "story-a" "failed" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "transition: in_review -> failed exits 0"
  else
    fail "transition: in_review -> failed should exit 0, got $EXIT_CODE — $OUTPUT"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 6: transition — failed to escalated succeeds
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh transition: failed -> escalated ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  "$SCRIPT" transition "$WS" "story-a" "in_progress" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "in_review" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "failed" >/dev/null 2>&1
  OUTPUT=$("$SCRIPT" transition "$WS" "story-a" "escalated" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "transition: failed -> escalated exits 0"
  else
    fail "transition: failed -> escalated should exit 0, got $EXIT_CODE — $OUTPUT"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 7: transition — escalated to in_progress succeeds
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh transition: escalated -> in_progress ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  "$SCRIPT" transition "$WS" "story-a" "in_progress" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "in_review" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "failed" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "escalated" >/dev/null 2>&1
  OUTPUT=$("$SCRIPT" transition "$WS" "story-a" "in_progress" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "transition: escalated -> in_progress exits 0"
  else
    fail "transition: escalated -> in_progress should exit 0, got $EXIT_CODE — $OUTPUT"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 8: dispatchable — returns story-a and story-c but not story-b
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh dispatchable: basic filtering ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  OUTPUT=$("$SCRIPT" dispatchable "$WS" 2>&1)
  EXIT_CODE=$?

  if echo "$OUTPUT" | grep -q "story-a"; then
    pass "dispatchable: includes story-a (pending, no deps)"
  else
    fail "dispatchable: should include story-a, got '$OUTPUT'"
  fi

  if echo "$OUTPUT" | grep -q "story-c"; then
    pass "dispatchable: includes story-c (pending, no deps)"
  else
    fail "dispatchable: should include story-c, got '$OUTPUT'"
  fi

  if ! echo "$OUTPUT" | grep -q "story-b"; then
    pass "dispatchable: excludes story-b (dep on 1 not merged)"
  else
    fail "dispatchable: should exclude story-b, got '$OUTPUT'"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 9: dispatchable — returns nothing when HALT file exists
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh dispatchable: HALT file blocks ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  touch "$WS/HALT"
  OUTPUT=$("$SCRIPT" dispatchable "$WS" 2>&1)
  if [ -z "$OUTPUT" ]; then
    pass "dispatchable: returns nothing when HALT file exists"
  else
    fail "dispatchable: should return nothing with HALT, got '$OUTPUT'"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 10: dispatchable — returns nothing when .scram-state is not "streams"
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh dispatchable: non-streams phase blocks ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  echo "G3" > "$WS/.scram-state"
  OUTPUT=$("$SCRIPT" dispatchable "$WS" 2>&1)
  if [ -z "$OUTPUT" ]; then
    pass "dispatchable: returns nothing when .scram-state is G3"
  else
    fail "dispatchable: should return nothing for G3 phase, got '$OUTPUT'"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 11: blocked — returns story-b (dep on story 1 not merged)
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh blocked: story-b blocked by story 1 ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  OUTPUT=$("$SCRIPT" blocked "$WS" 2>&1)

  if echo "$OUTPUT" | grep -q "story-b"; then
    pass "blocked: includes story-b (dep on 1 not merged)"
  else
    fail "blocked: should include story-b, got '$OUTPUT'"
  fi

  if ! echo "$OUTPUT" | grep -q "story-a"; then
    pass "blocked: excludes story-a (no deps)"
  else
    fail "blocked: should exclude story-a, got '$OUTPUT'"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 12: blocked — returns nothing after story 1 is merged
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh blocked: nothing after dep merged ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  # Move story-a (story #1) all the way to merged
  "$SCRIPT" transition "$WS" "story-a" "in_progress" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "in_review" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "merged" >/dev/null 2>&1

  OUTPUT=$("$SCRIPT" blocked "$WS" 2>&1)
  if ! echo "$OUTPUT" | grep -q "story-b"; then
    pass "blocked: story-b no longer blocked after story 1 merged"
  else
    fail "blocked: story-b should not be blocked after story 1 merged, got '$OUTPUT'"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 13: transition merged — type-drift retro entry
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-backlog.sh transition merged: type-drift retro ==="

if [ -f "$SCRIPT" ]; then
  WS=$(setup_workspace)
  mkdir -p "$WS/briefs"
  cat > "$WS/briefs/story-a.md" <<'BRIEF'
# story-a

Some description.

## Type Contracts

- Input: string
- Output: number
BRIEF

  # Move story-a to merged
  "$SCRIPT" transition "$WS" "story-a" "in_progress" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "in_review" >/dev/null 2>&1
  "$SCRIPT" transition "$WS" "story-a" "merged" >/dev/null 2>&1

  if [ -f "$WS/retro/in-flight.md" ] && grep -q "type-drift" "$WS/retro/in-flight.md"; then
    pass "transition merged: writes [type-drift] entry to retro/in-flight.md"
  else
    fail "transition merged: expected [type-drift] entry in retro/in-flight.md"
  fi
  rm -rf "$WS"
else
  fail "scram-backlog.sh does not exist"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failures:"
  echo -e "$ERRORS"
  exit 1
fi

exit 0
