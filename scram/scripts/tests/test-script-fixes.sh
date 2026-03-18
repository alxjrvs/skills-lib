#!/usr/bin/env bash
# test-script-fixes.sh — TDD tests for the 4 script bug fixes.
# RED: these tests should fail before the fixes are applied.
# GREEN: all tests pass after fixes.

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
# TEST GROUP 1: pre-merge-check.sh — Check 1 uses git rev-parse --verify
# Bug: git branch --list fails for branches in other worktrees
# ---------------------------------------------------------------------------
echo ""
echo "=== pre-merge-check.sh: Check 1 branch-exists ==="

# Verify the script no longer uses git branch --list for existence check
if grep -q 'git branch --list' "$SCRIPTS_DIR/pre-merge-check.sh"; then
  fail "pre-merge-check.sh still uses 'git branch --list' (should use git rev-parse --verify)"
else
  pass "pre-merge-check.sh does not use 'git branch --list'"
fi

# Verify it uses git rev-parse --verify instead
if grep -q 'git rev-parse --verify' "$SCRIPTS_DIR/pre-merge-check.sh"; then
  pass "pre-merge-check.sh uses 'git rev-parse --verify'"
else
  fail "pre-merge-check.sh does not use 'git rev-parse --verify'"
fi

# Verify exit behavior and output format preserved
TMPDIR_PMC=$(mktemp -d)
cd "$TMPDIR_PMC"
git init -q
git commit --allow-empty -m "init"
# Create a branch that exists
git checkout -q -b test-branch
git commit --allow-empty -m "story commit"
TEST_SHA=$(git rev-parse HEAD)
git checkout -q main 2>/dev/null || git checkout -q master 2>/dev/null || true

# Test: non-existent branch should fail with correct output
OUTPUT=$("$SCRIPTS_DIR/pre-merge-check.sh" "nonexistent-branch" "abc1234" "main" 2>&1 || true)
if echo "$OUTPUT" | grep -q "PRE_MERGE: fail" && echo "$OUTPUT" | grep -q "branch_exists"; then
  pass "pre-merge-check.sh: non-existent branch exits fail with correct output"
else
  fail "pre-merge-check.sh: non-existent branch output incorrect — got: $OUTPUT"
fi

# Test: existing branch passes Check 1 (will fail Check 2 with wrong SHA, which is fine)
OUTPUT=$("$SCRIPTS_DIR/pre-merge-check.sh" "test-branch" "$TEST_SHA" "main" 2>&1 || true)
if echo "$OUTPUT" | grep -q "PRE_MERGE: pass" || echo "$OUTPUT" | grep -q "sha_on_branch\|diff_non_empty"; then
  pass "pre-merge-check.sh: existing branch passes Check 1"
else
  fail "pre-merge-check.sh: existing branch Check 1 failed unexpectedly — got: $OUTPUT"
fi

cd /tmp
rm -rf "$TMPDIR_PMC"

# ---------------------------------------------------------------------------
# TEST GROUP 2: scram-init.sh — --nano flag
# Bug: --nano flag is documented but not implemented
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-init.sh: --nano flag ==="

# Verify the script handles --nano flag
if grep -q '\-\-nano' "$SCRIPTS_DIR/scram-init.sh"; then
  pass "scram-init.sh contains '--nano' flag handling"
else
  fail "scram-init.sh does not contain '--nano' flag handling"
fi

# Test: without --nano, all directories are created
TMPDIR_INIT=$(mktemp -d)
OUTPUT=$("$SCRIPTS_DIR/scram-init.sh" "$TMPDIR_INIT/full-workspace" 2>&1)
if [ -d "$TMPDIR_INIT/full-workspace/briefs" ] && \
   [ -d "$TMPDIR_INIT/full-workspace/retro" ] && \
   [ -d "$TMPDIR_INIT/full-workspace/events" ] && \
   [ -f "$TMPDIR_INIT/full-workspace/session.md" ]; then
  pass "scram-init.sh: without --nano creates briefs/, retro/, events/, session.md"
else
  fail "scram-init.sh: without --nano missing expected directories/files"
fi

# Test: with --nano, only events/ and session.md are created (no briefs/, no retro/)
TMPDIR_NANO=$(mktemp -d)
OUTPUT=$("$SCRIPTS_DIR/scram-init.sh" --nano "$TMPDIR_NANO/nano-workspace" 2>&1)
if [ -d "$TMPDIR_NANO/nano-workspace/events" ] && \
   [ -f "$TMPDIR_NANO/nano-workspace/session.md" ]; then
  pass "scram-init.sh: --nano creates events/ and session.md"
else
  fail "scram-init.sh: --nano missing events/ or session.md"
fi

if [ ! -d "$TMPDIR_NANO/nano-workspace/briefs" ]; then
  pass "scram-init.sh: --nano does NOT create briefs/"
else
  fail "scram-init.sh: --nano incorrectly created briefs/"
fi

if [ ! -d "$TMPDIR_NANO/nano-workspace/retro" ]; then
  pass "scram-init.sh: --nano does NOT create retro/"
else
  fail "scram-init.sh: --nano incorrectly created retro/"
fi

# Test: usage line updated
if grep -q '\-\-nano.*workspace-path\|workspace-path.*\-\-nano\|\[--nano\]' "$SCRIPTS_DIR/scram-init.sh"; then
  pass "scram-init.sh: usage line includes --nano"
else
  fail "scram-init.sh: usage line does not include --nano"
fi

rm -rf "$TMPDIR_INIT" "$TMPDIR_NANO"

# ---------------------------------------------------------------------------
# TEST GROUP 3: brief-lint.sh — false positive on port numbers
# Bug: :[0-9]+$ matches URLs like localhost:3000
# ---------------------------------------------------------------------------
echo ""
echo "=== brief-lint.sh: port number false positive ==="

# Verify the script does NOT use the bare :[0-9]+$ pattern
if grep -q ':\[0-9\]+\$' "$SCRIPTS_DIR/brief-lint.sh" && \
   ! grep -q 'localhost\|https\?\|http' "$SCRIPTS_DIR/brief-lint.sh"; then
  fail "brief-lint.sh still has bare ':[0-9]+\$' pattern without port exclusion"
else
  pass "brief-lint.sh pattern has been tightened (no bare :[0-9]+\$ without exclusion)"
fi

# Functional test: a URL with a port number should NOT trigger brief-lint
# Set up a minimal SCRAM workspace with a briefs/ dir
TMPDIR_LINT=$(mktemp -d)
mkdir -p "$TMPDIR_LINT/briefs"

# Content with a port at end of line — the actual false-positive case
# "localhost:3000" at EOL matches :[0-9]+$ and should NOT be flagged after the fix
URL_CONTENT='Run the dev server at localhost:3000'
JSON_WITH_URL=$(printf '{"file_path": "%s/briefs/test.md", "content": "%s"}' "$TMPDIR_LINT" "$URL_CONTENT")
LINT_OUTPUT=$(printf '%s' "$JSON_WITH_URL" | SCRAM_WORKSPACE="$TMPDIR_LINT" "$SCRIPTS_DIR/brief-lint.sh" 2>&1 || true)
if echo "$LINT_OUTPUT" | grep -q "BRIEF_LINT: fail"; then
  fail "brief-lint.sh: 'localhost:3000' at end of line incorrectly triggers line-number lint"
else
  pass "brief-lint.sh: 'localhost:3000' at end of line does not trigger false positive"
fi

# Also test https URL with port at EOL
HTTPS_CONTENT='API base: https://example.com:8080'
JSON_HTTPS=$(printf '{"file_path": "%s/briefs/test.md", "content": "%s"}' "$TMPDIR_LINT" "$HTTPS_CONTENT")
LINT_OUTPUT=$(printf '%s' "$JSON_HTTPS" | SCRAM_WORKSPACE="$TMPDIR_LINT" "$SCRIPTS_DIR/brief-lint.sh" 2>&1 || true)
if echo "$LINT_OUTPUT" | grep -q "BRIEF_LINT: fail"; then
  fail "brief-lint.sh: 'https://example.com:8080' at end of line incorrectly triggers lint"
else
  pass "brief-lint.sh: 'https://example.com:8080' at end of line does not trigger false positive"
fi

# Content with a genuine line number reference — SHOULD be flagged
LINE_CONTENT='See line 42 for the implementation.'
JSON_WITH_LINE=$(printf '{"file_path": "%s/briefs/test.md", "content": "%s"}' "$TMPDIR_LINT" "$LINE_CONTENT")
LINT_OUTPUT=$(printf '%s' "$JSON_WITH_LINE" | SCRAM_WORKSPACE="$TMPDIR_LINT" "$SCRIPTS_DIR/brief-lint.sh" 2>&1 || true)
if echo "$LINT_OUTPUT" | grep -q "BRIEF_LINT: fail"; then
  pass "brief-lint.sh: 'line 42' correctly triggers line-number lint"
else
  fail "brief-lint.sh: 'line 42' should trigger lint but did not"
fi

# Content with L-prefix reference — SHOULD be flagged
LREF_CONTENT='Refer to L99 in the source file.'
JSON_WITH_LREF=$(printf '{"file_path": "%s/briefs/test.md", "content": "%s"}' "$TMPDIR_LINT" "$LREF_CONTENT")
LINT_OUTPUT=$(printf '%s' "$JSON_WITH_LREF" | SCRAM_WORKSPACE="$TMPDIR_LINT" "$SCRIPTS_DIR/brief-lint.sh" 2>&1 || true)
if echo "$LINT_OUTPUT" | grep -q "BRIEF_LINT: fail"; then
  pass "brief-lint.sh: 'L99' correctly triggers line-number lint"
else
  fail "brief-lint.sh: 'L99' should trigger lint but did not"
fi

rm -rf "$TMPDIR_LINT"

# ---------------------------------------------------------------------------
# TEST GROUP 4: scram-discover.sh — uses git root, not pwd basename
# Bug: basename "$PWD" breaks when invoked from a subdirectory
# ---------------------------------------------------------------------------
echo ""
echo "=== scram-discover.sh: git root project name detection ==="

# Verify the script uses git rev-parse --show-toplevel instead of bare basename "$PWD"
if grep -q 'basename "\$PWD"' "$SCRIPTS_DIR/scram-discover.sh" && \
   ! grep -q 'show-toplevel' "$SCRIPTS_DIR/scram-discover.sh"; then
  fail "scram-discover.sh still uses bare 'basename \"\$PWD\"' without git show-toplevel"
else
  pass "scram-discover.sh uses git-based root detection"
fi

# Functional test: create a fake project and SCRAM session, then invoke from a subdir
TMPDIR_DISC=$(mktemp -d)
FAKE_PROJECT="$TMPDIR_DISC/MyProject"
mkdir -p "$FAKE_PROJECT/subdir"
cd "$FAKE_PROJECT"
git init -q
git commit --allow-empty -m "init"

# Create a fake SCRAM session for "MyProject"
mkdir -p "$TMPDIR_DISC/.scram/MyProject--test-session--20260318-000000"
cat > "$TMPDIR_DISC/.scram/MyProject--test-session--20260318-000000/session.md" << 'EOF'
---
current_gate: "G2"
updated: 2026-03-18T00:00:00Z
---
EOF

# Test: from project root
OUTPUT=$(HOME="$TMPDIR_DISC" "$SCRIPTS_DIR/scram-discover.sh" 2>&1)
if echo "$OUTPUT" | grep -q "MyProject"; then
  pass "scram-discover.sh: finds sessions from project root"
else
  fail "scram-discover.sh: does not find sessions from root — got: $OUTPUT"
fi

# Test: from a subdirectory — should still find "MyProject" sessions
cd "$FAKE_PROJECT/subdir"
OUTPUT=$(HOME="$TMPDIR_DISC" "$SCRIPTS_DIR/scram-discover.sh" 2>&1)
if echo "$OUTPUT" | grep -q "MyProject"; then
  pass "scram-discover.sh: finds sessions when invoked from subdirectory"
else
  fail "scram-discover.sh: fails to find sessions from subdirectory — got: $OUTPUT"
fi

cd /tmp
rm -rf "$TMPDIR_DISC"

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
