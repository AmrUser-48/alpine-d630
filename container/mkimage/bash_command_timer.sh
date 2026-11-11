#!/usr/bin/env bash
# Readline-safe derivative of bash-command-timer.
# Frozen pre-refactor baseline: upstream/bash_command_timer.sh
# Original copyright: Chuan Ji, 2014-2020. Apache-2.0; see LICENSE.

if [[ -z ${BASH_VERSION:-} ]]; then
    return 0
fi
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    printf '%s\n' 'bash_command_timer.sh must be sourced, not executed.' >&2
    exit 2
fi
if [[ ${BCT_LOADED:-0} == 1 ]]; then
    return 0
fi

: "${BCT_ENABLE:=1}"
: "${BCT_SUCCESS_COLOR:=34}"
: "${BCT_ERROR_COLOR:=91}"
: "${BCT_TIME_FORMAT=%b %d %I:%M%p}"
: "${BCT_MILLIS:=1}"
: "${BCT_COLOR_OUTPUT:=1}"

# Keep the timer inside PS1; never move the terminal cursor from PROMPT_COMMAND.
BCT_BASE_PS1=${BCT_BASE_PS1-${PS1-}}
BCT_TIMER_PROMPT_PREFIX=''
BCT_COMMAND_START_NS=''
BCT_AT_PROMPT=1
BCT_FIRST_PROMPT=1
BCT_LAST_STATUS=0
BCT_USE_BASH_PREEXEC=0

_bct_now_ns() {
    local stamp=${EPOCHREALTIME-}
    if [[ $stamp == *.* ]]; then
        BCT_NOW_NS="${stamp/./}000"
        return 0
    fi

    local value
    value=$(date +%s%N 2>/dev/null) || value=''
    if [[ $value =~ ^[0-9]+$ ]]; then
        BCT_NOW_NS=$value
        return 0
    fi
    value=$(date +%s 2>/dev/null) || return 1
    [[ $value =~ ^[0-9]+$ ]] || return 1
    BCT_NOW_NS="${value}000000000"
}

_bct_format_duration() {
    local elapsed_ns=${1:-0}
    case $elapsed_ns in (''|*[!0123456789]*) elapsed_ns=0;; esac

    local total_seconds=$((elapsed_ns / 1000000000)) days hours minutes seconds milliseconds result='' msec=''
    days=$((total_seconds / 86400))
    hours=$((total_seconds % 86400 / 3600))
    minutes=$((total_seconds % 3600 / 60))
    seconds=$((total_seconds % 60))
    milliseconds=$((elapsed_ns / 1000000 % 1000))

    (( days > 0 )) && result+="${days}d "
    (( hours > 0 )) && result+="${hours}h "
    (( minutes > 0 )) && result+="${minutes}m "
    result+="${seconds}s"
    if [[ ${BCT_MILLIS:-1} == 1 ]]; then
        printf -v msec '%03d' "$milliseconds"
        result+="$msec"
    fi
    BCT_FORMATTED_DURATION=$result
}

_bct_make_prompt_prefix() {
    local elapsed_ns=${1:-0} command_status=${2:-0}
    local time_str now_str='' output_str color='' columns padding pad
    _bct_format_duration "$elapsed_ns"
    time_str=${BCT_FORMATTED_DURATION:-0s000}
    if [[ -n ${BCT_TIME_FORMAT:-} ]]; then
        # Bash printf's %(...)T formatter avoids spawning date for each prompt.
        printf -v now_str "%(${BCT_TIME_FORMAT})T" -1 2>/dev/null || now_str=''
    fi

    if [[ -n $now_str ]]; then
        output_str="[ $time_str | $now_str ]"
    else
        output_str="[ $time_str ]"
    fi

    if [[ ${BCT_COLOR_OUTPUT:-1} == 1 && ${TERM:-dumb} != dumb ]]; then
        if [[ $command_status -eq 0 ]]; then
            color=${BCT_SUCCESS_COLOR:-34}
        else
            color=${BCT_ERROR_COLOR:-91}
        fi
    fi

    columns=${COLUMNS:-80}
    [[ $columns != *[!0123456789]* ]] && (( columns > 0 )) || columns=80
    padding=$((columns - ${#output_str}))
    (( padding < 0 )) && padding=0
    printf -v pad '%*s' "$padding" ''

    # Readline counts the printable row and ignores only ANSI sequences marked
    # as nonprinting with \[ and \]. Newlines separate output from the prompt.
    if [[ -n $color ]]; then
        printf -v BCT_TIMER_PROMPT_PREFIX '\\n%s\\[\\e[%sm\\]%s\\[\\e[0m\\]\\n' \
            "$pad" "$color" "$output_str"
    else
        printf -v BCT_TIMER_PROMPT_PREFIX '\\n%s%s\\n' "$pad" "$output_str"
    fi
}

_bct_preexec() {
    if [[ ${BCT_AT_PROMPT:-0} != 1 ]]; then
        return 0
    fi
    BCT_AT_PROMPT=0
    if _bct_now_ns; then
        BCT_COMMAND_START_NS=$BCT_NOW_NS
    else
        BCT_COMMAND_START_NS=''
    fi
    return 0
}

_bct_restore_prompt() {
    PS1=${BCT_BASE_PS1-}
    return 0
}

_bct_capture_status() {
    BCT_LAST_STATUS=$?
    PS1=${BCT_BASE_PS1-}
    return 0
}

_bct_postcmd() {
    local command_status
    if [[ ${BCT_USE_BASH_PREEXEC:-0} == 1 ]]; then
        command_status=$?
    else
        command_status=${BCT_LAST_STATUS:-0}
    fi

    # Capture any prompt changed by another precmd hook, without stacking timers.
    BCT_BASE_PS1=${PS1-}
    BCT_AT_PROMPT=1

    if [[ ${BCT_FIRST_PROMPT:-0} == 1 ]]; then
        BCT_FIRST_PROMPT=0
        BCT_COMMAND_START_NS=''
        BCT_TIMER_PROMPT_PREFIX=''
        PS1=$BCT_BASE_PS1
        return "$command_status"
    fi

    if [[ ${BCT_ENABLE:-1} != 1 || -z ${BCT_COMMAND_START_NS:-} ]]; then
        BCT_COMMAND_START_NS=''
        BCT_TIMER_PROMPT_PREFIX=''
        PS1=$BCT_BASE_PS1
        return "$command_status"
    fi

    local end_ns elapsed_ns
    if _bct_now_ns; then
        end_ns=$BCT_NOW_NS
    else
        end_ns=''
    fi
    if [[ -z $end_ns ]]; then
        BCT_COMMAND_START_NS=''
        BCT_TIMER_PROMPT_PREFIX=''
        PS1=$BCT_BASE_PS1
        return "$command_status"
    fi

    elapsed_ns=$((end_ns - BCT_COMMAND_START_NS))
    (( elapsed_ns < 0 )) && elapsed_ns=0
    BCT_COMMAND_START_NS=''
    _bct_make_prompt_prefix "$elapsed_ns" "$command_status"
    PS1="${BCT_TIMER_PROMPT_PREFIX}${BCT_BASE_PS1}"
    return "$command_status"
}

# Helpers can be tested by noninteractive Bash, but hooks are interactive-only.
[[ $- == *i* ]] || return 0

# Prefer bash-preexec so existing DEBUG/PROMPT_COMMAND hooks can be composed.
_f2x_preexec_path=''
if [[ -n ${BASH_PREEXEC_LOCATION:-} && -r ${BASH_PREEXEC_LOCATION} ]]; then
    _f2x_preexec_path=$BASH_PREEXEC_LOCATION
elif [[ -n ${bash_preexec_imported:-} || -n ${__bp_imported:-} ]]; then
    _f2x_preexec_path='already-loaded'
elif [[ -r /usr/share/bash-preexec/bash-preexec.sh ]]; then
    _f2x_preexec_path=/usr/share/bash-preexec/bash-preexec.sh
elif [[ -r $HOME/.bash-preexec.sh ]]; then
    _f2x_preexec_path=$HOME/.bash-preexec.sh
fi

if [[ -n $_f2x_preexec_path ]]; then
    if [[ $_f2x_preexec_path != already-loaded ]]; then
        source "$_f2x_preexec_path" || _f2x_preexec_path=''
    fi
    if [[ -n ${bash_preexec_imported:-} || -n ${__bp_imported:-} ]]; then
        BCT_USE_BASH_PREEXEC=1
        declare -p precmd_functions >/dev/null 2>&1 || precmd_functions=()
        declare -p preexec_functions >/dev/null 2>&1 || preexec_functions=()
        precmd_functions=(_bct_restore_prompt "${precmd_functions[@]}" _bct_postcmd)
        preexec_functions+=( _bct_preexec )
        BCT_LOADED=1
        unset _f2x_preexec_path
        return 0
    fi
fi

# Never overwrite another script's DEBUG trap. Disable the timer instead.
if [[ -n $(trap -p DEBUG) ]]; then
    printf '%s\n' 'bash-command-timer: existing DEBUG trap detected; timer disabled to preserve it. Install bash-preexec to compose hooks.' >&2
    unset _f2x_preexec_path
    return 0
fi

# Skip the function call unless the first command after a prompt starts.
trap '[[ ${BCT_AT_PROMPT:-0} != 1 ]] || _bct_preexec' DEBUG

# Preserve PROMPT_COMMAND (scalar or Bash 5.1+ array), including exit status.
_f2x_prompt_decl=$(declare -p PROMPT_COMMAND 2>/dev/null) || _f2x_prompt_decl=''
if [[ $_f2x_prompt_decl =~ ^declare\ -a[[:space:]] ]]; then
    PROMPT_COMMAND=(_bct_capture_status "${PROMPT_COMMAND[@]}" _bct_postcmd)
else
    _f2x_previous_prompt_command=${PROMPT_COMMAND-}
    PROMPT_COMMAND='_bct_capture_status'
    if [[ -n $_f2x_previous_prompt_command ]]; then
        PROMPT_COMMAND+=$'\n'"$_f2x_previous_prompt_command"
    fi
    PROMPT_COMMAND+=$'\n_bct_postcmd'
fi

BCT_LOADED=1
unset _f2x_preexec_path _f2x_prompt_decl _f2x_previous_prompt_command

