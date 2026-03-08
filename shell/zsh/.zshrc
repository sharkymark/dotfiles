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

# Jon's avante.nvim fork path (https://github.com/jonmorehouse/avante.nvim)
# Override on machines where the fork lives elsewhere
export AVANTE_FORK_PATH="$HOME/Documents/dev_and_debug/src/mark/avante.nvim"

# Nuon-related
alias nuonctl='~/nuonco/mono/run-nuonctl.sh'
alias nuonstage="nuon -f ~/.stage"

# starship cross-shell prompt
# https://starship.rs/
eval "$(starship init zsh)"


#prompt
#PS1="%n@%m %1~ %# "
#PS1="🍋 %1~ %# "
