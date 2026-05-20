#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

DANGEROUS_PATTERNS="rm -rf|git push.*--force|git push.*-f|git reset --hard|git clean -fd"

if echo "$COMMAND" | grep -iE "$DANGEROUS_PATTERNS" >/dev/null 2>&1; then
  echo "BLOCKED: 破壊的操作を検出しました: $(echo "$COMMAND" | head -1)" >&2
  exit 2
fi
exit 0
