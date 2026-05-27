#!/bin/bash
# 最新リリースを取得し Haiku で日本語要約してキャッシュに保存する（バックグラウンド更新用）
# このスクリプトは startup-tips.sh から非ブロッキングで起動される。単独・cron でも実行可。
set -uo pipefail

CACHE_DIR="$HOME/.config/claude/cache"
CACHE_FILE="$CACHE_DIR/startup-tips.txt"
LOCK_DIR="$CACHE_DIR/.startup-tips.lock"
LOG_FILE="$CACHE_DIR/startup-tips-update.log"
API_URL="https://api.github.com/repos/anthropics/claude-code/releases/latest"

mkdir -p "$CACHE_DIR"

# 多重実行防止: mkdir はアトミック。既に更新中なら即終了。
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

{
  echo "=== update start: $(date) ==="

  # 1. 最新リリース取得（失敗時はキャッシュ温存してサイレント終了）
  RELEASE_JSON=$(curl -sf --max-time 15 "$API_URL") || { echo "curl failed"; exit 0; }

  # 2. Haiku で日本語要約。CLAUDE_TIPS_SKIP=1 で startup-tips フックの再帰発火を防止。
  #    （--bare は OAuth/keychain 認証を読まず "Not logged in" で失敗するため使わない）
  #    リリース JSON は stdin で渡し、指示は prompt 引数で渡す。
  PROMPT='標準入力は Claude Code の GitHub 最新リリース情報(JSON)です。ユーザーが起動時にひと目で把握できるよう、新機能・改善点を日本語で5項目以内の箇条書き(各1行・先頭に「・」)に要約してください。1行目はバージョン番号を含む見出し「Claude Code <version> の新機能」にしてください。前置き・後書き・コードブロックは一切不要で、見出しと箇条書きのみを出力してください。'

  SUMMARY=$(printf '%s' "$RELEASE_JSON" \
    | CLAUDE_TIPS_SKIP=1 claude -p --model haiku --max-budget-usd 0.05 "$PROMPT" 2>>"$LOG_FILE") \
    || { echo "claude summarize failed"; exit 0; }

  # 空応答ならキャッシュ温存
  if [ -z "${SUMMARY//[[:space:]]/}" ]; then
    echo "empty summary, keep old cache"
    exit 0
  fi

  # 3. アトミック書き込み（tmp → mv）。書き込み途中のキャッシュを読ませない。
  TMP_FILE=$(mktemp "$CACHE_DIR/.startup-tips.XXXXXX")
  printf '%s\n' "$SUMMARY" > "$TMP_FILE"
  mv "$TMP_FILE" "$CACHE_FILE"
  echo "=== update done: $(date) ==="
} >> "$LOG_FILE" 2>&1
