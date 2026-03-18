#!/usr/bin/env bash
# pre-merge-check.sh — Run three git reads to confirm a story branch is mergeable.
# Usage: pre-merge-check.sh <branch-name> <commit-sha> <integration-branch>
# Exit 0: all checks pass
# Exit 1: one or more checks failed

if [ $# -lt 3 ]; then
  echo "Usage: pre-merge-check.sh <branch-name> <commit-sha> <integration-branch>" >&2
  exit 1
fi

BRANCH_NAME="$1"
COMMIT_SHA="$2"
INTEGRATION_BRANCH="$3"

# Check 1: branch exists
BRANCH_EXISTS=$(git branch --list "$BRANCH_NAME")
if [ -z "$BRANCH_EXISTS" ]; then
  echo "PRE_MERGE: fail"
  echo "  check: branch_exists"
  echo "  reason: branch '$BRANCH_NAME' does not exist"
  exit 1
fi

# Check 2: SHA is on branch
SHA_ON_BRANCH=$(git log --oneline "$BRANCH_NAME" 2>/dev/null | grep "$COMMIT_SHA")
if [ -z "$SHA_ON_BRANCH" ]; then
  echo "PRE_MERGE: fail"
  echo "  check: sha_on_branch"
  echo "  reason: commit '$COMMIT_SHA' not found on branch '$BRANCH_NAME'"
  exit 1
fi

# Check 3: diff is non-empty
DIFF_OUTPUT=$(git diff "${INTEGRATION_BRANCH}...${BRANCH_NAME}" 2>/dev/null)
if [ -z "$DIFF_OUTPUT" ]; then
  echo "PRE_MERGE: fail"
  echo "  check: diff_non_empty"
  echo "  reason: no diff between '$INTEGRATION_BRANCH' and '$BRANCH_NAME'"
  exit 1
fi

echo "PRE_MERGE: pass"
echo "  branch: $BRANCH_NAME"
echo "  sha: $COMMIT_SHA"
echo "  diff: non-empty"
exit 0
