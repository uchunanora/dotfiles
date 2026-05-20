#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -iE '\b(DROP|TRUNCATE|DELETE\s+FROM|ALTER|INSERT|UPDATE)\b' >/dev/null 2>&1; then
  echo "BLOCKED: 破壊的SQLコマンドを検出しました: $(echo "$COMMAND" | head -1)" >&2
  exit 2
fi
exit 0
