#!/usr/bin/env bash
# worktree-init.sh — Verify worktree isolation and create story branch.
# Usage: worktree-init.sh <integration-branch> <story-slug>
# Exit 0: worktree verified, story branch created
# Exit 1: not in a worktree
# Exit 2: worktree not branched from integration branch
# Exit 3: story branch creation failed
# Exit 4: HEAD not on story branch after creation

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: worktree-init.sh <integration-branch> <story-slug>" >&2
  exit 1
fi

INTEGRATION_BRANCH="$1"
STORY_SLUG="$2"

# Derive feature name from integration branch (e.g., scram/my-feature -> my-feature)
FEATURE_NAME="${INTEGRATION_BRANCH#scram/}"
STORY_BRANCH="scram/${FEATURE_NAME}/${STORY_SLUG}"

WORKTREE_PATH="$(pwd)"

# Check 1: Confirm current directory is a git worktree (not the main repo)
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
MAIN_WORKTREE="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"

if [ "$TOPLEVEL" = "$MAIN_WORKTREE" ]; then
  echo "FAIL: Not in a worktree — current directory is the main repo at $TOPLEVEL" >&2
  echo "  worktree_path: $WORKTREE_PATH" >&2
  echo "  main_repo: $MAIN_WORKTREE" >&2
  exit 1
fi
echo "CHECK 1 PASSED: In worktree at $TOPLEVEL (main repo at $MAIN_WORKTREE)"

# Check 2: Confirm the worktree was created from the integration branch
MERGE_BASE="$(git merge-base HEAD "$INTEGRATION_BRANCH" 2>/dev/null || true)"
INTEGRATION_TIP="$(git rev-parse --verify "$INTEGRATION_BRANCH" 2>/dev/null || true)"

if [ -z "$MERGE_BASE" ] || [ -z "$INTEGRATION_TIP" ]; then
  echo "FAIL: Cannot find integration branch '$INTEGRATION_BRANCH'" >&2
  echo "  worktree_path: $WORKTREE_PATH" >&2
  echo "  integration_branch: $INTEGRATION_BRANCH" >&2
  exit 2
fi

if [ "$MERGE_BASE" != "$INTEGRATION_TIP" ]; then
  echo "FAIL: Worktree HEAD is not based on integration branch tip" >&2
  echo "  worktree_path: $WORKTREE_PATH" >&2
  echo "  integration_branch: $INTEGRATION_BRANCH" >&2
  echo "  integration_tip: $INTEGRATION_TIP" >&2
  echo "  merge_base: $MERGE_BASE" >&2
  exit 2
fi
echo "CHECK 2 PASSED: Worktree is based on $INTEGRATION_BRANCH ($INTEGRATION_TIP)"

# Check 3: Create the story branch from the integration branch
if ! git checkout -b "$STORY_BRANCH" 2>/dev/null; then
  echo "FAIL: Could not create story branch '$STORY_BRANCH'" >&2
  echo "  worktree_path: $WORKTREE_PATH" >&2
  echo "  story_branch: $STORY_BRANCH" >&2
  exit 3
fi
echo "CHECK 3 PASSED: Created story branch $STORY_BRANCH"

# Check 4: Verify HEAD is on the new story branch
CURRENT_BRANCH="$(git branch --show-current)"

if [ "$CURRENT_BRANCH" != "$STORY_BRANCH" ]; then
  echo "FAIL: HEAD is on '$CURRENT_BRANCH', expected '$STORY_BRANCH'" >&2
  echo "  worktree_path: $WORKTREE_PATH" >&2
  echo "  expected_branch: $STORY_BRANCH" >&2
  echo "  actual_branch: $CURRENT_BRANCH" >&2
  exit 4
fi
echo "CHECK 4 PASSED: HEAD is on $STORY_BRANCH"

echo ""
echo "Worktree isolation verified:"
echo "  worktree_path: $WORKTREE_PATH"
echo "  story_branch: $STORY_BRANCH"
echo "  integration_branch: $INTEGRATION_BRANCH"
echo "  all_checks: passed"
