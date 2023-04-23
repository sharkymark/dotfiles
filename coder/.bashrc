
export DISPLAY

# colors
red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m'

# https://ss64.com/bash/syntax-prompt.html

if [[ "${DISPLAY#$HOST}" != ":0.0" &&  "${DISPLAY}" != ":0" ]]; then  
    HILIT=${red}   # remote machine
else
    HILIT=${NC}  # local machine
fi

function prompt()
{
    unset PROMPT_COMMAND
    PS1="🦈 [\h] \W % "
}

prompt