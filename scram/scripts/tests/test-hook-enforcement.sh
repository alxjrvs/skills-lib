#!/usr/bin/env bash
# test-hook-enforcement.sh — TDD tests for isolation-check.sh and merge-guard.sh.
# RED: these tests should fail before the scripts are created.
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
# TEST GROUP 1: isolation-check.sh — file existence and basic structure
# ---------------------------------------------------------------------------
echo ""
echo "=== isolation-check.sh: existence ==="

if [ -f "$SCRIPTS_DIR/isolation-check.sh" ]; then
  pass "isolation-check.sh exists"
else
  fail "isolation-check.sh does not exist at $SCRIPTS_DIR/isolation-check.sh"
fi

if [ -x "$SCRIPTS_DIR/isolation-check.sh" ]; then
  pass "isolation-check.sh is executable"
else
  fail "isolation-check.sh is not executable"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 2: isolation-check.sh — no-op when SCRAM_WORKSPACE unset
# ---------------------------------------------------------------------------
echo ""
echo "=== isolation-check.sh: guard on SCRAM_WORKSPACE ==="

if [ -f "$SCRIPTS_DIR/isolation-check.sh" ]; then
  # With no SCRAM_WORKSPACE, should exit 0 (no-op)
  OUTPUT=$(echo '{}' | env -u SCRAM_WORKSPACE "$SCRIPTS_DIR/isolation-check.sh" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "isolation-check.sh: exits 0 when SCRAM_WORKSPACE is unset"
  else
    fail "isolation-check.sh: should exit 0 when SCRAM_WORKSPACE is unset, got $EXIT_CODE"
  fi
else
  fail "isolation-check.sh: skip (file not found)"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 3: isolation-check.sh — no HALT when no worktrees need checking
# ---------------------------------------------------------------------------
echo ""
echo "=== isolation-check.sh: no-op when no isolation failure ==="

if [ -f "$SCRIPTS_DIR/isolation-check.sh" ]; then
  TMPDIR_IC=$(mktemp -d)
  mkdir -p "$TMPDIR_IC"

  # No worktrees file or empty workspace — should exit 0
  OUTPUT=$(echo '{}' | SCRAM_WORKSPACE="$TMPDIR_IC" "$SCRIPTS_DIR/isolation-check.sh" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "isolation-check.sh: exits 0 when workspace exists but no isolation failure"
  else
    fail "isolation-check.sh: unexpected non-zero exit for empty workspace — got $EXIT_CODE"
  fi

  # Should NOT write HALT file when exit 0
  if [ ! -f "$TMPDIR_IC/HALT" ]; then
    pass "isolation-check.sh: does not write HALT when no failure"
  else
    fail "isolation-check.sh: incorrectly wrote HALT file"
  fi

  rm -rf "$TMPDIR_IC"
else
  fail "isolation-check.sh: skip (file not found)"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 4: merge-guard.sh — file existence and basic structure
# ---------------------------------------------------------------------------
echo ""
echo "=== merge-guard.sh: existence ==="

if [ -f "$SCRIPTS_DIR/merge-guard.sh" ]; then
  pass "merge-guard.sh exists"
else
  fail "merge-guard.sh does not exist at $SCRIPTS_DIR/merge-guard.sh"
fi

if [ -x "$SCRIPTS_DIR/merge-guard.sh" ]; then
  pass "merge-guard.sh is executable"
else
  fail "merge-guard.sh is not executable"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 5: merge-guard.sh — no-op when SCRAM_WORKSPACE unset
# ---------------------------------------------------------------------------
echo ""
echo "=== merge-guard.sh: guard on SCRAM_WORKSPACE ==="

if [ -f "$SCRIPTS_DIR/merge-guard.sh" ]; then
  # With no SCRAM_WORKSPACE, should always exit 0 regardless of command
  OUTPUT=$(printf '{"command":"git merge some-branch"}' | env -u SCRAM_WORKSPACE "$SCRIPTS_DIR/merge-guard.sh" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "merge-guard.sh: exits 0 for git merge when SCRAM_WORKSPACE is unset"
  else
    fail "merge-guard.sh: should exit 0 when SCRAM_WORKSPACE is unset, got $EXIT_CODE"
  fi
else
  fail "merge-guard.sh: skip (file not found)"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 6: merge-guard.sh — non-merge commands pass through
# ---------------------------------------------------------------------------
echo ""
echo "=== merge-guard.sh: pass-through for non-merge commands ==="

if [ -f "$SCRIPTS_DIR/merge-guard.sh" ]; then
  TMPDIR_MG=$(mktemp -d)

  # git status — should pass
  OUTPUT=$(printf '{"command":"git status"}' | SCRAM_WORKSPACE="$TMPDIR_MG" "$SCRIPTS_DIR/merge-guard.sh" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "merge-guard.sh: exits 0 for git status"
  else
    fail "merge-guard.sh: git status should exit 0, got $EXIT_CODE"
  fi

  # npm install — should pass
  OUTPUT=$(printf '{"command":"npm install"}' | SCRAM_WORKSPACE="$TMPDIR_MG" "$SCRIPTS_DIR/merge-guard.sh" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "merge-guard.sh: exits 0 for npm install"
  else
    fail "merge-guard.sh: npm install should exit 0, got $EXIT_CODE"
  fi

  # git commit — should pass
  OUTPUT=$(printf '{"command":"git commit -m feat: add something"}' | SCRAM_WORKSPACE="$TMPDIR_MG" "$SCRIPTS_DIR/merge-guard.sh" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -eq 0 ]; then
    pass "merge-guard.sh: exits 0 for git commit"
  else
    fail "merge-guard.sh: git commit should exit 0, got $EXIT_CODE"
  fi

  rm -rf "$TMPDIR_MG"
else
  fail "merge-guard.sh: skip (file not found)"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 7: merge-guard.sh — git merge without pre-merge-check.sh args
# When git merge is detected but no approved args, should exit non-zero
# ---------------------------------------------------------------------------
echo ""
echo "=== merge-guard.sh: intercepts git merge commands ==="

if [ -f "$SCRIPTS_DIR/merge-guard.sh" ]; then
  TMPDIR_MG2=$(mktemp -d)
  mkdir -p "$TMPDIR_MG2"

  # Plain 'git merge some-branch' — should be intercepted (exits non-zero)
  OUTPUT=$(printf '{"command":"git merge some-branch"}' | SCRAM_WORKSPACE="$TMPDIR_MG2" "$SCRIPTS_DIR/merge-guard.sh" 2>&1)
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -ne 0 ]; then
    pass "merge-guard.sh: intercepts plain 'git merge some-branch' (exits non-zero)"
  else
    fail "merge-guard.sh: should block 'git merge some-branch' but exited 0"
  fi

  # Output should explain the block
  if echo "$OUTPUT" | grep -qi "merge\|guard\|block\|SCRAM"; then
    pass "merge-guard.sh: output explains why merge was intercepted"
  else
    fail "merge-guard.sh: output does not explain interception — got: $OUTPUT"
  fi

  rm -rf "$TMPDIR_MG2"
else
  fail "merge-guard.sh: skip (file not found)"
fi

# ---------------------------------------------------------------------------
# TEST GROUP 8: hooks.json — PostToolUse and Bash PreToolUse entries
# ---------------------------------------------------------------------------
echo ""
echo "=== hooks.json: new hook entries ==="

HOOKS_FILE="$(dirname "$SCRIPTS_DIR")/hooks/hooks.json"

if [ -f "$HOOKS_FILE" ]; then
  # PostToolUse key must exist
  if grep -q '"PostToolUse"' "$HOOKS_FILE"; then
    pass "hooks.json: contains PostToolUse key"
  else
    fail "hooks.json: missing PostToolUse key"
  fi

  # Agent matcher for PostToolUse
  if grep -q '"Agent"' "$HOOKS_FILE"; then
    pass "hooks.json: contains Agent matcher"
  else
    fail "hooks.json: missing Agent matcher in PostToolUse"
  fi

  # isolation-check.sh reference
  if grep -q 'isolation-check.sh' "$HOOKS_FILE"; then
    pass "hooks.json: references isolation-check.sh"
  else
    fail "hooks.json: missing isolation-check.sh reference"
  fi

  # merge-guard.sh reference
  if grep -q 'merge-guard.sh' "$HOOKS_FILE"; then
    pass "hooks.json: references merge-guard.sh"
  else
    fail "hooks.json: missing merge-guard.sh reference"
  fi

  # Bash matcher for PreToolUse merge-guard
  if grep -q '"Bash"' "$HOOKS_FILE"; then
    pass "hooks.json: contains Bash matcher for PreToolUse"
  else
    fail "hooks.json: missing Bash matcher in PreToolUse"
  fi

  # Valid JSON
  if command -v jq &>/dev/null; then
    if jq empty "$HOOKS_FILE" 2>/dev/null; then
      pass "hooks.json: is valid JSON"
    else
      fail "hooks.json: invalid JSON"
    fi
  else
    pass "hooks.json: jq not available, skipping JSON validation"
  fi
else
  fail "hooks.json: not found at $HOOKS_FILE"
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
