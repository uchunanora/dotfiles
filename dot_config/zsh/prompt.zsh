for f in \
  /opt/homebrew/etc/bash_completion.d/git-prompt.sh \
  /usr/local/etc/bash_completion.d/git-prompt.sh \
  /Library/Developer/CommandLineTools/usr/share/git-core/git-prompt.sh; do
  [[ -r $f ]] && source $f && break
done

GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWSTASHSTATE=1
GIT_PS1_SHOWUPSTREAM=auto

autoload -Uz add-zsh-hook

__update_prompt() {
  local last_status=$?

  if (( last_status == 0 )); then
    PROMPT_FACE='%F{green}(*'\''-'\'') < %f'
  else
    PROMPT_FACE='%F{blue}(*;-;) < %f'
  fi

  local pwd_short="${PWD/#$HOME/~}"
  if (( ${#pwd_short} > COLUMNS - 10 )); then
    local -a parts
    parts=("${(@s:/:)pwd_short}")
    local i
    for (( i = 1; i < ${#parts}; i++ )); do
      if [[ -z ${parts[i]} ]]; then
        continue
      elif [[ ${parts[i]} == .* ]]; then
        parts[i]="${parts[i][1,2]}"
      else
        parts[i]="${parts[i][1]}"
      fi
    done
    psvar[1]="${(j:/:)parts}"
  else
    psvar[1]="$pwd_short"
  fi
}
add-zsh-hook precmd __update_prompt

setopt PROMPT_SUBST
PS1='╭─ %F{blue}%B%1v%b%f %F{yellow}$(__git_ps1 "<%s>")%f
╰─${PROMPT_FACE}'

RPROMPT='%F{8}%*%f'
