if [ -f ~/.debian_bash ]; then
    . ~/.debian_bash
fi

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

export PATH="$PATH:/sbin:/home/nathan/bin"

#####################################################
# Misc.
#####################################################
alias cls='clear'
alias la='ls -al'

function cda() {
    if [[ -z "$1" ]]; then
        target=~
    else
        target="$1"
    fi
    cd "$target"
    la
}

# Edit .bashrc and re-source it
alias bashrc='vim ~/.bash_aliases; source ~/.bashrc'

alias new-password='openssl rand -base64 32'

export VISUAL=vim
export EDITOR="$VISUAL"

png-to-ico() {
  local src="$1"
  [ -f "$src" ] || { echo "Usage: to_ico <image-file>"; return 1; }
  local out="${src%.*}.ico"
  convert "$src" -define icon:auto-resize=256,128,64,48,32,16 "$out"
  echo "$out"
}
alias here='wslpath -w .'
alias aria2c='aria2c -c -j 10 -s 10 -x 10'

#####################################################
# Git shortcuts
#####################################################
alias ga='git status'
alias gb='git branch -a'
alias gl='git log --oneline'

#####################################################
# View disk usage of CWD
#####################################################
shopt -s dotglob
if command -v sudo > /dev/null 2>&1; then
    alias disk-usage='sudo du -sh ./* | sort -hr'
else
    alias disk-usage='du -sh ./* | sort -hr'
fi

# Search for file by name
function find-file() {
    if [ -z "$1" ]; then
        echo "Usage: find-file <phrase> [directory]"
        return 1
    fi

    local search_dir="${2:-.}"
    find "$search_dir" -iname "*$1*"
}


#####################################################
# Docker shortcuts
#####################################################
alias logs='docker logs -f'
alias dps='docker ps'
alias dstopall='docker stop $(docker ps -a -q)'
alias dremoveall='docker rm $(docker ps -a -q); docker network prune -f'

# Enter Docker containers as shell
function denter() {
    if [[ -z "$1" ]]; then
        echo "Usage: denter <container-id>"
        return 1
    fi
    docker exec -it "$1" /bin/bash
}
function denter_sh() {
    if [[ -z "$1" ]]; then
        echo "Usage: denter <container-id>"
        return 1
    fi
    docker exec -it "$1" /bin/sh
}

# Kill Docker container process if things have gone terribly wrong
function dfind_process() {
    if [[ -z "$1" ]]; then
        echo "Usage: dfind_process <container-id>"
        return 1
    fi

    container_id=$(docker container ls | grep "$1" | awk '{print $1}')
    if [[ ! "$container_id" ]]; then
        echo "No container found for name '$1'"
        return 1
    fi

    pgrep -f "$container_id"
}

#####################################################
# SWAG utilities
#####################################################
alias nginx='cd /home/nathan/swag/config/nginx/proxy-confs; la *.conf'
alias nginx-logs='cda /home/nathan/swag/config/log/nginx'
alias bans='grep "ban " /home/nathan/swag/config/log/fail2ban/fail2ban.log --ignore-case'
alias unban='docker exec swag fail2ban-client unban'
alias fail2ban='cat /home/nathan/swag/config/log/fail2ban/fail2ban.log'
