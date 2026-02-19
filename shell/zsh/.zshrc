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

#prompt
#PS1="%n@%m %1~ %# "
PS1="🍋 %1~ %# "