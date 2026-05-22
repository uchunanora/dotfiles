# chpwd: cdしたら自動でlsa
chpwd() {
  lsa
}

# peco: 履歴検索
function peco-select-history() {
  BUFFER=$(\history -n -r 1 | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N peco-select-history
bindkey '^r' peco-select-history

# yazi: ディレクトリ移動連携
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# wtc: 説明文からClaudeがブランチ名を生成してworktree作成 (wt switch -c のラッパー)
#   例) wtc "ログイン画面のバグ修正" -> fix/login-screen-bug を生成して確認後に作成
function wtc() {
  emulate -L zsh
  [[ -z "$*" ]] && { print -u2 'usage: wtc "<description>"'; return 1; }
  local desc="$*" branch ans
  local prompt='Generate ONE git branch name from the description below.
Rules: output ONLY the branch name on a single line, no quotes, no explanation.
Use a Conventional Commits type prefix (feat/, fix/, docs/, refactor/, chore/, etc.).
Translate to concise lowercase English kebab-case. Example: "fix/login-screen-bug".
Description: '"$desc"
  while true; do
    print -u2 -- "Generating…"
    branch=$(claude -p --model haiku "$prompt" </dev/null 2>/dev/null \
             | grep -oE '[a-z]+/[a-z0-9._-]+' | head -n1)
    if [[ -z "$branch" ]]; then
      print -u2 -- "Generation failed. Retrying…"
      continue
    fi
    print -r -- "Generated: $branch"
    read "ans?[Enter=write / r=regenerate / q=quit] "
    case "$ans" in
      ''|y|Y) break ;;
      r|R) continue ;;
      *) print -- "Aborted"; return 1 ;;
    esac
  done
  # 実行はせず、コマンドラインに書き込むだけ (自分でEnterして実行)
  print -z "wt switch -c ${(q)branch}"
}
