#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -q 'git add'; then
  if echo "$COMMAND" | grep -iE '\.(env|pem|key|p12|pfx|credentials)|credentials|\.secret' >/dev/null 2>&1; then
    echo "BLOCKED: 機密ファイルのステージングを検出しました" >&2
    exit 2
  fi
fi
exit 0
