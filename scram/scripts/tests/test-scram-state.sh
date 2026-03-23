#!/usr/bin/env bash
# test-scram-state.sh — TDD tests for scram-state.sh gate state machine.
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

# ---------------------------------------------------------------------------
# TEST GROUP 1: init creates .scram-state with G0 and events/ directory
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh init: creates state file and events dir ==="

TMPDIR_INIT=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  OUTPUT=$("$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_INIT/ws" 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "init exits 0"
  else
    fail "init should exit 0, got $EXIT_CODE"
  fi

  if [ -f "$TMPDIR_INIT/ws/.scram-state" ]; then
    pass "init creates .scram-state file"
  else
    fail "init does not create .scram-state file"
  fi

  STATE=$(cat "$TMPDIR_INIT/ws/.scram-state" 2>/dev/null)
  if [ "$STATE" = "G0" ]; then
    pass "init sets state to G0"
  else
    fail "init should set state to G0, got: $STATE"
  fi

  if [ -d "$TMPDIR_INIT/ws/events" ]; then
    pass "init creates events/ directory"
  else
    fail "init does not create events/ directory"
  fi
else
  fail "scram-state.sh does not exist at $SCRIPTS_DIR/scram-state.sh"
  fail "skipping init tests (file not found)"
fi

rm -rf "$TMPDIR_INIT"

# ---------------------------------------------------------------------------
# TEST GROUP 2: current reads and prints current state
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh current: reads state ==="

TMPDIR_CUR=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_CUR/ws" >/dev/null 2>&1

  OUTPUT=$("$SCRIPTS_DIR/scram-state.sh" current "$TMPDIR_CUR/ws" 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "current exits 0"
  else
    fail "current should exit 0, got $EXIT_CODE"
  fi

  if [ "$OUTPUT" = "G0" ]; then
    pass "current prints G0 after init"
  else
    fail "current should print G0, got: $OUTPUT"
  fi
else
  fail "scram-state.sh not found — skipping current tests"
fi

rm -rf "$TMPDIR_CUR"

# ---------------------------------------------------------------------------
# TEST GROUP 3: advance from G0 to G1 succeeds
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh advance: valid transition G0 -> G1 ==="

TMPDIR_ADV=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_ADV/ws" >/dev/null 2>&1

  OUTPUT=$("$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_ADV/ws" G1 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "advance G0->G1 exits 0"
  else
    fail "advance G0->G1 should exit 0, got $EXIT_CODE"
  fi

  STATE=$(cat "$TMPDIR_ADV/ws/.scram-state" 2>/dev/null)
  if [ "$STATE" = "G1" ]; then
    pass "advance G0->G1 updates state file to G1"
  else
    fail "advance G0->G1 should update state to G1, got: $STATE"
  fi

  # Check event was logged
  if [ -f "$TMPDIR_ADV/ws/events/stream.log" ]; then
    if grep -q '"type":"gate"' "$TMPDIR_ADV/ws/events/stream.log" && \
       grep -q '"gate":"G1"' "$TMPDIR_ADV/ws/events/stream.log"; then
      pass "advance G0->G1 logs gate event to stream.log"
    else
      fail "advance G0->G1 event log missing expected fields"
    fi
  else
    fail "advance G0->G1 does not create events/stream.log"
  fi
else
  fail "scram-state.sh not found — skipping advance tests"
fi

rm -rf "$TMPDIR_ADV"

# ---------------------------------------------------------------------------
# TEST GROUP 4: advance out of order (G0 to G3) fails
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh advance: out-of-order transition G0 -> G3 fails ==="

TMPDIR_OOO=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_OOO/ws" >/dev/null 2>&1

  OUTPUT=$("$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_OOO/ws" G3 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -ne 0 ]; then
    pass "advance G0->G3 exits non-zero"
  else
    fail "advance G0->G3 should fail, but exited 0"
  fi

  if echo "$OUTPUT" | grep -qi "invalid\|error\|cannot\|expected"; then
    pass "advance G0->G3 outputs error message"
  else
    fail "advance G0->G3 should output error message, got: $OUTPUT"
  fi

  # State should remain G0
  STATE=$(cat "$TMPDIR_OOO/ws/.scram-state" 2>/dev/null)
  if [ "$STATE" = "G0" ]; then
    pass "advance G0->G3 does not change state"
  else
    fail "advance G0->G3 should leave state as G0, got: $STATE"
  fi
else
  fail "scram-state.sh not found — skipping out-of-order tests"
fi

rm -rf "$TMPDIR_OOO"

# ---------------------------------------------------------------------------
# TEST GROUP 5: advance with --skip flag records gate_skip event
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh advance --skip: records gate_skip event ==="

TMPDIR_SKIP=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_SKIP/ws" >/dev/null 2>&1

  OUTPUT=$("$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_SKIP/ws" G1 --skip 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "advance --skip G0->G1 exits 0"
  else
    fail "advance --skip G0->G1 should exit 0, got $EXIT_CODE"
  fi

  STATE=$(cat "$TMPDIR_SKIP/ws/.scram-state" 2>/dev/null)
  if [ "$STATE" = "G1" ]; then
    pass "advance --skip updates state to G1"
  else
    fail "advance --skip should update state to G1, got: $STATE"
  fi

  if [ -f "$TMPDIR_SKIP/ws/events/stream.log" ]; then
    if grep -q '"type":"gate_skip"' "$TMPDIR_SKIP/ws/events/stream.log"; then
      pass "advance --skip logs gate_skip event type"
    else
      fail "advance --skip should log type gate_skip"
    fi
  else
    fail "advance --skip does not create events/stream.log"
  fi
else
  fail "scram-state.sh not found — skipping --skip tests"
fi

rm -rf "$TMPDIR_SKIP"

# ---------------------------------------------------------------------------
# TEST GROUP 6: check returns exit 0 for reached gates, exit 1 for unreached
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh check: reached vs unreached gates ==="

TMPDIR_CHK=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_CHK/ws" >/dev/null 2>&1
  "$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_CHK/ws" G1 >/dev/null 2>&1
  "$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_CHK/ws" G2 >/dev/null 2>&1

  # G0 was passed — should exit 0
  "$SCRIPTS_DIR/scram-state.sh" check "$TMPDIR_CHK/ws" G0 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    pass "check G0 (passed gate) exits 0"
  else
    fail "check G0 (passed gate) should exit 0"
  fi

  # G1 was passed — should exit 0
  "$SCRIPTS_DIR/scram-state.sh" check "$TMPDIR_CHK/ws" G1 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    pass "check G1 (passed gate) exits 0"
  else
    fail "check G1 (passed gate) should exit 0"
  fi

  # G2 is current — should exit 0
  "$SCRIPTS_DIR/scram-state.sh" check "$TMPDIR_CHK/ws" G2 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    pass "check G2 (current gate) exits 0"
  else
    fail "check G2 (current gate) should exit 0"
  fi

  # G3 not reached — should exit 1
  "$SCRIPTS_DIR/scram-state.sh" check "$TMPDIR_CHK/ws" G3 >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    pass "check G3 (unreached gate) exits non-zero"
  else
    fail "check G3 (unreached gate) should exit non-zero"
  fi

  # streams not reached — should exit 1
  "$SCRIPTS_DIR/scram-state.sh" check "$TMPDIR_CHK/ws" streams >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    pass "check streams (unreached gate) exits non-zero"
  else
    fail "check streams (unreached gate) should exit non-zero"
  fi
else
  fail "scram-state.sh not found — skipping check tests"
fi

rm -rf "$TMPDIR_CHK"

# ---------------------------------------------------------------------------
# TEST GROUP 7: require returns exit 0 only when current gate matches exactly
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh require: exact match only ==="

TMPDIR_REQ=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_REQ/ws" >/dev/null 2>&1
  "$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_REQ/ws" G1 >/dev/null 2>&1

  # G1 is current — should exit 0
  "$SCRIPTS_DIR/scram-state.sh" require "$TMPDIR_REQ/ws" G1 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    pass "require G1 (current) exits 0"
  else
    fail "require G1 (current) should exit 0"
  fi

  # G0 is passed but not current — should exit 1
  "$SCRIPTS_DIR/scram-state.sh" require "$TMPDIR_REQ/ws" G0 >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    pass "require G0 (passed, not current) exits non-zero"
  else
    fail "require G0 (passed, not current) should exit non-zero"
  fi

  # G2 is unreached — should exit 1
  "$SCRIPTS_DIR/scram-state.sh" require "$TMPDIR_REQ/ws" G2 >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    pass "require G2 (unreached) exits non-zero"
  else
    fail "require G2 (unreached) should exit non-zero"
  fi
else
  fail "scram-state.sh not found — skipping require tests"
fi

rm -rf "$TMPDIR_REQ"

# ---------------------------------------------------------------------------
# TEST GROUP 8: full transition sequence G0 through complete
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh: full transition sequence ==="

TMPDIR_FULL=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_FULL/ws" >/dev/null 2>&1
  ALL_PASS=true

  for GATE in G1 G2 G3 streams G4 G5 complete; do
    OUTPUT=$("$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_FULL/ws" "$GATE" 2>&1)
    EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ]; then
      fail "full sequence: advance to $GATE failed (exit $EXIT_CODE) — $OUTPUT"
      ALL_PASS=false
    fi
  done

  if [ "$ALL_PASS" = true ]; then
    pass "full sequence: all transitions G0->G1->G2->G3->streams->G4->G5->complete succeed"
  fi

  STATE=$(cat "$TMPDIR_FULL/ws/.scram-state" 2>/dev/null)
  if [ "$STATE" = "complete" ]; then
    pass "full sequence: final state is complete"
  else
    fail "full sequence: final state should be complete, got: $STATE"
  fi

  # Verify event log has entries for all gates
  if [ -f "$TMPDIR_FULL/ws/events/stream.log" ]; then
    LOG_LINES=$(wc -l < "$TMPDIR_FULL/ws/events/stream.log" | tr -d ' ')
    if [ "$LOG_LINES" -eq 7 ]; then
      pass "full sequence: stream.log has 7 event entries"
    else
      fail "full sequence: stream.log should have 7 entries, got $LOG_LINES"
    fi
  else
    fail "full sequence: events/stream.log not found"
  fi
else
  fail "scram-state.sh not found — skipping full sequence tests"
fi

rm -rf "$TMPDIR_FULL"

# ---------------------------------------------------------------------------
# TEST GROUP 9: advance past complete fails
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-state.sh advance: past complete fails ==="

TMPDIR_PAST=$(mktemp -d)

if [ -f "$SCRIPTS_DIR/scram-state.sh" ]; then
  "$SCRIPTS_DIR/scram-state.sh" init "$TMPDIR_PAST/ws" >/dev/null 2>&1
  for GATE in G1 G2 G3 streams G4 G5 complete; do
    "$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_PAST/ws" "$GATE" >/dev/null 2>&1
  done

  # Try to advance past complete — should fail
  OUTPUT=$("$SCRIPTS_DIR/scram-state.sh" advance "$TMPDIR_PAST/ws" G0 2>&1)
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -ne 0 ]; then
    pass "advance past complete exits non-zero"
  else
    fail "advance past complete should fail, but exited 0"
  fi

  STATE=$(cat "$TMPDIR_PAST/ws/.scram-state" 2>/dev/null)
  if [ "$STATE" = "complete" ]; then
    pass "advance past complete does not change state"
  else
    fail "advance past complete should leave state as complete, got: $STATE"
  fi
else
  fail "scram-state.sh not found — skipping past-complete tests"
fi

rm -rf "$TMPDIR_PAST"

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
