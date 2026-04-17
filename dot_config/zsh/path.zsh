# Path Settings
typeset -U path PATH # Remove dupulicates

path=(
  $HOME/.local/bin
  $HOME/.rd/bin
  /opt/homebrew/bin(N-/)
  /opt/homebrew/sbin(N-/)
  "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  "/Applications/WezTerm.app/Contents/MacOS"
  $path
)
