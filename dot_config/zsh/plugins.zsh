# nvm (lazy load)
if [ -d ${HOME}/.nvm ]; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  nvm() {
    unset -f nvm
    source "${NVM_DIR}/nvm.sh"
    nvm "$@"
  }

  if [ -f "${NVM_DIR}/alias/default" ]; then
    DEFAULT_NODE_VERSION=$(cat "${NVM_DIR}/alias/default")
    NODE_BIN_PATH="${NVM_DIR}/versions/node/v${DEFAULT_NODE_VERSION}/bin"
    if [ -d "${NODE_BIN_PATH}" ]; then
      export PATH="${NODE_BIN_PATH}:$PATH"
      export NODE_PATH="${NVM_DIR}/versions/node/v${DEFAULT_NODE_VERSION}/lib/node_modules"
    fi
  fi
fi

# git-completion
fpath=(~/.zsh $fpath)
zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash
autoload -Uz compinit && compinit

# sheldon
eval "$(sheldon source)"

# fzf
source <(fzf --zsh)

# zoxide
eval "$(zoxide init zsh --hook prompt)"
