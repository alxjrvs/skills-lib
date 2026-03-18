#!/usr/bin/env bash
# brief-lint.sh — Detect line-number references in a context brief file.
# Registered as PreToolUse on Write. Reads file_path from stdin JSON.
# Exit 0: no line-number references found (or not a brief file)
# Exit 1: line-number references detected

# Read file path from stdin JSON (Write tool hook input)
STDIN_JSON=$(cat)

# Extract file_path from JSON using jq if available, otherwise grep/sed
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$STDIN_JSON" | jq -r '.file_path // empty' 2>/dev/null)
else
  FILE_PATH=$(echo "$STDIN_JSON" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
fi

# If no file path found, exit 0 (no-op)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# If SCRAM_WORKSPACE is unset, exit 0 (no-op)
if [ -z "${SCRAM_WORKSPACE:-}" ]; then
  exit 0
fi

# Self-filter: only lint files under $SCRAM_WORKSPACE/briefs/
BRIEFS_DIR="$SCRAM_WORKSPACE/briefs"
case "$FILE_PATH" in
  "$BRIEFS_DIR"/*) ;;  # file is under briefs/, proceed
  *) exit 0 ;;         # not a brief file, no-op
esac

# File doesn't exist yet (Write tool creates it) — lint the content from stdin if provided
# For pre-write linting, check the content field if available
if command -v jq &>/dev/null; then
  CONTENT=$(echo "$STDIN_JSON" | jq -r '.content // empty' 2>/dev/null)
else
  # Fallback: extract content field with sed (best effort)
  CONTENT=$(echo "$STDIN_JSON" | grep -o '"content"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"content"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
fi

# If we have content to lint, use it; otherwise try to read the file
if [ -n "$CONTENT" ]; then
  LINT_TARGET=$(echo "$CONTENT")
elif [ -f "$FILE_PATH" ]; then
  LINT_TARGET=$(cat "$FILE_PATH")
else
  # No content to lint, exit 0
  exit 0
fi

# Grep for line-number patterns
MATCHES=$(echo "$LINT_TARGET" | grep -nE '(line [0-9]+|:[0-9]+$|L[0-9]+)' 2>/dev/null || true)

if [ -n "$MATCHES" ]; then
  echo "BRIEF_LINT: fail $FILE_PATH"
  echo "  Line-number references detected (use content-anchored locators instead):"
  while IFS= read -r MATCH_LINE; do
    echo "  > $MATCH_LINE"
  done <<< "$MATCHES"
  exit 1
fi

echo "BRIEF_LINT: pass $FILE_PATH"
exit 0
