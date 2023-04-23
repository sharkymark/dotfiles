
export EDITOR='code -w'

# docker socket symlink if it is missing - needed for docker desktop to build images and create and start containers
if [ ! -L '/var/run/docker.sock' ]; then
    sudo ln -s "$HOME/.docker/run/docker.sock" /var/run/docker.sock;
fi

# for debugging later
#ls -lah /var/run/docker.sock
#ls -lah ~/.docker/run/docker.sock

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
#prompt
#PS1="%n@%m %1~ %# "
PS1="🦈 %1~ %# "

# ruby environment manager rbenv initialization
eval "$(rbenv init -)"