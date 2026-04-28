# zsh configurations
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=999999
export HISTFILESIZE=999999
export SAVEHIST=$HISTSIZE
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS

# initialize completion
autoload -U compinit; compinit
_comp_options+=(globdots) # With hidden files

# Atuin - enhanced shell history (https://atuin.sh)
if command -v atuin &> /dev/null; then
  eval "$(atuin init zsh)"
else
  echo "💡 Atuin not installed — run: brew install atuin"
fi

# Nuon-related
alias nuonctl='~/nuonco/mono/run-nuonctl.sh'
alias nuonstage="nuon -f ~/.stage"

# starship cross-shell prompt
# https://starship.rs/
# eval "$(starship init zsh)"

# for email prospecting
chrome-debug() {
  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port=9222 \
    --user-data-dir="$HOME/.chrome-debug-profile" \
    --profile-directory="Profile 1" \
    2>/dev/null &
}

#prompt
#PS1="%n@%m %1~ %# "
#PS1="🍋 %1~ %# "
