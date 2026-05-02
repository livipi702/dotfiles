# ~/.bashrc: executed by bash(1) for non-login shells.

case $- in
*i*) ;;
*) return ;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

if [ -n "$force_color_prompt" ]; then
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
color_prompt=yes
else
color_prompt=
fi
fi

if [ "$color_prompt" = yes ]; then
PS1='${debian_chroot:+($debian_chroot)}[\033[01;32m]\u@\h[\033[00m]:[\033[01;34m]\w[\033[00m]$ '
else
PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w$ '
fi
unset color_prompt force_color_prompt

case "$TERM" in
xterm* | rxvt*)
PS1="[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a]$PS1"
;;
*) ;;
esac

if [ -x /usr/bin/dircolors ]; then
test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'


if [ -f ~/.bash_aliases ]; then
. ~/.bash_aliases
fi

if ! shopt -oq posix; then
if [ -f /usr/share/bash-completion/bash_completion ]; then
. /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
. /etc/bash_completion
fi
fi

add_to_path() {
case ":$PATH:" in
*":$1:"*) ;;
*) PATH="$1:$PATH" ;;
esac
}

# ======================== DATABASE SETUP ========================

[ -f "$HOME/setup-scripts/database.sh" ] && source "$HOME/setup-scripts/database.sh"

# ====================================================================

# ======================== GLOBAL SETUP SCRIPTS ========================

[ -x "$HOME/setup-scripts/install-node.sh" ] && alias install-node="$HOME/setup-scripts/install-node.sh"
[ -x "$HOME/setup-scripts/install-mongo.sh" ] && alias install-mongo="$HOME/setup-scripts/install-mongo.sh"
[ -x "$HOME/setup-scripts/install-redis.sh" ] && alias install-redis="$HOME/setup-scripts/install-redis.sh"
[ -x "$HOME/setup-scripts/concat.sh" ] && alias concat="$HOME/setup-scripts/concat.sh"

# ====================================================================

# ======================== PS1 SETUP ========================

[ -f "$HOME/setup-scripts/prompt.sh" ] && source "$HOME/setup-scripts/prompt.sh"

# ====================================================================

[ -f "$HOME/dev-journey/05-scripts/common-aliases.sh" ] && source "$HOME/dev-journey/05-scripts/common-aliases.sh"

alias now='date "+%A, %d %B %Y - %I:%M:%S %p %Z"'

# ======================== JAVA SETUP ========================

if command -v java >/dev/null 2>&1; then
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(which java)")")")
add_to_path "$JAVA_HOME/bin"
fi

# ============================================================

# ======================== PATH ADDITIONS ========================

add_to_path "$HOME/.npm-global/bin"
add_to_path "$HOME/.local/bin"

# ====================================================================

export EDITOR=nvim
export VISUAL=nvim
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e '\''s/^[[:space:]]*[0-9]\+[[:space:]]*//;s/[;&|][[:space:]]*alert$//'\'')"'
