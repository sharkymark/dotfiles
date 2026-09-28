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
alias oxf='npx --yes oxfmt@0.52.0'

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

# Google Drive Notes shortcut — works whether this Mac uses the old
# "<email> - Google Drive" mount or the new ~/Library/CloudStorage format
_gdrive_email="mtm20176@gmail.com"
_gdrive_new="$HOME/Library/CloudStorage/GoogleDrive-${_gdrive_email}/My Drive/Notes"
_gdrive_old="$HOME/${_gdrive_email} - Google Drive/My Drive/Notes"

if [ -d "$_gdrive_new" ]; then
  export GDRIVE_NOTES="$_gdrive_new"
elif [ -d "$_gdrive_old" ]; then
  export GDRIVE_NOTES="$_gdrive_old"
fi

if [ -n "$GDRIVE_NOTES" ]; then
  alias notes="cd \"$GDRIVE_NOTES\""
fi

unset _gdrive_email _gdrive_new _gdrive_old


#prompt
#PS1="%n@%m %1~ %# "
#PS1="🍋 %1~ %# "
