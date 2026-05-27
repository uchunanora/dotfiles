#!/bin/bash
# 起動時にキャッシュ済みの新機能 Tips を表示し、古ければ更新をバックグラウンド起動する。
# 表示専用: ネットも LLM も触らないため起動を一切ブロックしない（stale-while-revalidate）。
# SessionStart(matcher:startup) フックから呼ばれる。
#
# 表示方式: フックの子プロセスは制御端末を持たない（/dev/tty は ENXIO で開けない）ため、
# JSON の systemMessage を stdout に出力して TUI に表示させる。

# update-startup-tips.sh 内の claude -p から再帰的に発火するのを防ぐ（無限ループ防止）
if [ -n "${CLAUDE_TIPS_SKIP:-}" ]; then
  exit 0
fi

CACHE_DIR="$HOME/.config/claude/cache"
CACHE_FILE="$CACHE_DIR/startup-tips.txt"
UPDATER="$HOME/.config/claude/hooks/update-startup-tips.sh"
MAX_AGE=3600  # 鮮度しきい値: 1時間

# 1. キャッシュがあれば systemMessage(JSON) を stdout に出力 → TUI に表示される。
#    jq -Rs でキャッシュ全文を1つの文字列として安全にエスケープする。
if [ -s "$CACHE_FILE" ]; then
  jq -Rs '{systemMessage: ("\n💡 CC Tips\n" + .)}' "$CACHE_FILE" 2>/dev/null
else
  echo '{"systemMessage": "\n💡 Claude Code の新機能を取得中です。次回起動時に表示されます。"}'
fi

# 2. 鮮度チェック → 古ければ（または未取得なら）バックグラウンドで更新をキック
need_update=1
if [ -f "$CACHE_FILE" ]; then
  mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [ $((now - mtime)) -lt "$MAX_AGE" ]; then
    need_update=0
  fi
fi

if [ "$need_update" -eq 1 ] && [ -x "$UPDATER" ]; then
  nohup "$UPDATER" >/dev/null 2>&1 &
fi

exit 0
