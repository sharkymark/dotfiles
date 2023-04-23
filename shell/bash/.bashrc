
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=999999
export HISTFILESIZE=999999
export SAVEHIST=$HISTSIZE
# append to the history file instead of overwriting it when shell closed
shopt -s histappend


# colors
red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m'

# https://ss64.com/bash/syntax-prompt.html
# https://www.gnu.org/software/bash/manual/html_node/Controlling-the-Prompt.html

function prompt()
{
    unset PROMPT_COMMAND
    PS1="🦈 \W \$ "
}

prompt