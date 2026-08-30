export PATH="/opt/homebrew/opt/node@24/bin:$PATH"

# Homebrew 6.0 made `--ask` the default for install/reinstall/upgrade; never prompt.
export HOMEBREW_NO_ASK=1

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
alias nctl='~/nuonco/mono/run-nuonctl.sh'
alias nuonstage="nuon --config ~/.stage"

# AI-related
alias claudeteam='env -u ANTHROPIC_API_KEY claude'
alias ca='cursor-agent'

# Ghostty: blinking block cursor (bar override if integration already loaded).
if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
  _ghostty_block_cursor() { print -n $'\e[1 q' >&2; }
  precmd_functions+=(_ghostty_block_cursor)
  if (( ${+functions[_ghostty_zle_line_init]} )); then
    functions[_ghostty_zle_line_init_orig]=$functions[_ghostty_zle_line_init]
    _ghostty_zle_line_init() {
      _ghostty_zle_line_init_orig "$@"
      _ghostty_block_cursor
    }
    zle -N zle-line-init _ghostty_zle_line_init
    zle -N zle-keymap-select _ghostty_zle_keymap_select
  fi
fi

# starship cross-shell prompt
# https://starship.rs/
eval "$(starship init zsh)"

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
