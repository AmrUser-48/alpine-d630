# Interactive Bash configuration for Alpine D630.
case $- in
    *i*) ;;
      *) return ;;
esac

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-FRX'
export HISTCONTROL=ignoreboth

HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend cmdhist checkwinsize
bind 'set enable-bracketed-paste on'

# Compact prompt; keep Readline's nonprinting ANSI sequences bracketed.
case "$TERM" in
    xterm*|rxvt*|*-256color)
        PS1='\\[\\e]0;\\u@\\h: \\w\\a\\]\\[\\e[01;32m\\]\\u@\\h\\[\\e[00m\\]:\\[\\e[01;34m\\]\\w\\[\\e[00m\\]\\$ '
        ;;
    *)
        PS1='\\[\\e[01;32m\\]\\u@\\h\\[\\e[00m\\]:\\[\\e[01;34m\\]\\w\\[\\e[00m\\]\\$ '
        ;;
esac

# Show when lf starts a subshell.
if [[ -n ${LF_LEVEL-} ]]; then
    PS1='\\[\\e[01;34m\\][ \\[\\e[01;32m\\]lf\\[\\e[01;34m\\] ]\\[\\e[00m\\] '$PS1
fi

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

lfcd() {
    local tmp dir status
    tmp=$(mktemp) || return
    lf -last-dir-path="$tmp" "$@"
    status=$?
    if [[ -s $tmp ]]; then
        IFS= read -r dir < "$tmp"
        if [[ -d $dir && $dir != "$PWD" ]]; then
            builtin cd -- "$dir"
        fi
    fi
    rm -f -- "$tmp"
    return "$status"
}

# Ctrl+O opens lf and returns to the directory selected on exit.
bind '"\\C-o":"\\C-u lfcd\\C-m"'

# Timer is sourced only for interactive shells; it composes with PROMPT_COMMAND.
BCT_MILLIS=1
BCT_COLOR_OUTPUT=1
BCT_TIME_FORMAT='%b %d %I:%M%p'
[ -r "$HOME/.local/lib/bash-command-timer/bash_command_timer.sh" ] && \
    source "$HOME/.local/lib/bash-command-timer/bash_command_timer.sh"

[ -r "$HOME/.bash_aliases" ] && source "$HOME/.bash_aliases"
