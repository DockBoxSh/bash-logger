#!/usr/bin/env bash

#--------------------------------------------------------------------------------------------------
# Bash Logger
# Copyright (c) Dean Rather
# Copyright (c) Hexosse
# Licensed under the MIT license
# http://github.com/dockbox/bash-logger
#--------------------------------------------------------------------------------------------------

# Fail on first error
set -e

#--------------------------------------------------------------------------------------------------
# Configurables

# RFC-5424 log levels
declare -A LOG_LEVELS
export LOG_LEVELS=([DEBUG]=7 [INFO]=6 [NOTICE]=5 [WARNING]=4 [ERROR]=3 [CRITICAL]=2 [ALERT]=1 [EMERGENCY]=0)

# LOG variables
export LOGFILE="$HOME/bash-logger.log"
export LOG_FORMAT='%DATE %PID [%LEVEL] %MESSAGE'
export LOG_DATE_FORMAT='+%F %T %Z'                  # Eg: 2014-09-07 21:51:57 EST
export LOG_COLOR_ENABLE=1                           # Enable colors by default
export LOG_LEVEL=${LOG_LEVELS[DEBUG]}               # Logs all messages to the terminal
export LOG_COLOR_DEBUG="\033[0;34m"                 # Blue
export LOG_COLOR_INFO="\033[0;37m"                  # White
export LOG_COLOR_NOTICE="\033[1;32m"                # Green
export LOG_COLOR_WARNING="\033[1;33m"               # Yellow
export LOG_COLOR_ERROR="\033[1;31m"                 # Red
export LOG_COLOR_CRITICAL="\033[44m"                # Blue Background
export LOG_COLOR_ALERT="\033[45m"                   # Purple Background
export LOG_COLOR_EMERGENCY="\033[41m"               # Red Background
export RESET_COLOR="\033[0m"

#--------------------------------------------------------------------------------------------------
# Individual Log Functions
# These can be overwritten to provide custom behavior for different log levels

DEBUG()     { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; }
INFO()      { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; }
NOTICE()    { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; }
WARNING()   { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; }
ERROR()     { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; exit 1; }
CRITICAL()  { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; exit 1; }
ALERT()     { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; exit 1; }
EMERGENCY() { LOG_HANDLER_DEFAULT "$FUNCNAME" "$@"; exit 1; }

#--------------------------------------------------------------------------------------------------
# Helper Functions

# Outputs a log formatted using the LOG_FORMAT and DATE_FORMAT configurables
# Usage: FORMAT_LOG <log level> <log message>
# Eg: FORMAT_LOG CRITICAL "My critical log"
FORMAT_LOG() {
    local level="$1"
    local log="$2"
    local pid=$$
    local date="$(date "$LOG_DATE_FORMAT")"
    local formatted_log="$LOG_FORMAT"
    formatted_log="${formatted_log/'%MESSAGE'/$log}"
    formatted_log="${formatted_log/'%LEVEL'/$level}"
    formatted_log="${formatted_log/'%PID'/$pid}"
    formatted_log="${formatted_log/'%DATE'/$date}"

    # 
    echo "$formatted_log"
}

# Calls one of the individual log functions
# Usage: LOG <log level> <log message>
# Eg: LOG INFO "My info log"
LOG() {
    local level="$1"
    local log="$2"
    local log_function_name="${level^^}"
    $log_function_name "$log"
}

# Get the level value from level name
# Eg: LOG_LEVEL_VALUE <DEBUG | INFO | ...>
LOG_LEVEL_VALUE() {
    local level="${1}"
    [ -z "${LOG_LEVELS[$level]+isset}" ] && return 1
    echo "${LOG_LEVELS[$level]}"
}

# Get log level name from numeric value.
# Eg: LOG_LEVEL_NAME <0..7>
LOG_LEVEL_NAME() {
    local level=""
    local value="${1}"
    for level in "${!LOG_LEVELS[@]}"; do
       [ "${LOG_LEVELS[$level]}" -eq "${value}" ] && echo "${level}" && return 0
    done
    return 1
}

#--------------------------------------------------------------------------------------------------
# Log Handlers

# All log levels call this handler (by default...), so this is a great place to put any standard
# logging behavior
# Usage: LOG_HANDLER_DEFAULT <log level> <log message>
# Eg: LOG_HANDLER_DEFAULT DEBUG "My debug log"
LOG_HANDLER_DEFAULT() {
    # Normal log
    if [ -t 0 ]; then
        LOG_HANDLER_OUT "$@"
    fi

    # From pipe
    if [ ! -t 0 ]; then
        local level="$1"
        shift
        while read -r line; do
            args=()
            if [ -n "$*" ]; then
                args+=( "$@" )
            fi
            args+=( "${line}" );
            LOG_HANDLER_OUT "$level" "${args[*]}"
        done
    fi
}

# Used by LOG_HANDLER_DEFAULT to output the log
LOG_HANDLER_OUT(){
    local level="$1"
    local formatted_log="$(FORMAT_LOG "$@")"
    [ "${LOG_COLOR_ENABLE}" -eq "1" ] && LOG_HANDLER_COLORTERM "$level" "$formatted_log"
    [ "${LOG_COLOR_ENABLE}" -ne "1" ] && LOG_HANDLER_TERM "$level" "$formatted_log"
    LOG_HANDLER_LOGFILE "$level" "$formatted_log"
}

# Outputs a log to the stdout, colourised using the LOG_COLOR configurables
# Usage: LOG_HANDLER_COLORTERM <log level> <log message>
# Eg: LOG_HANDLER_COLORTERM CRITICAL "My critical log"
LOG_HANDLER_COLORTERM() {
    local level="$1"
    local level_value="$(LOG_LEVEL_VALUE "$level")"
    local log="$2"
    local color_variable="LOG_COLOR_$level"
    local color="${!color_variable}"
    log="$color$log$RESET_COLOR"

    [ "${level_value}" -gt "$LOG_LEVEL" ] && return 0
    echo -e "$log"
}

# Outputs a log to the stdout, without color
# Usage: LOG_HANDLER_TERM <log level> <log message>
# Eg: LOG_HANDLER_TERM CRITICAL "My critical log"
LOG_HANDLER_TERM() {
    local level="$1"
    local level_value="$(LOG_LEVEL_VALUE "$level")"
    local log="$2"

    [ "${level_value}" -gt "$LOG_LEVEL" ] && return 0
    echo -e "$log"
}

# Appends a log to the configured logfile
# Usage: LOG_HANDLER_LOGFILE <log level> <log message>
# Eg: LOG_HANDLER_LOGFILE NOTICE "My critical log"
LOG_HANDLER_LOGFILE() {
    local level="$1"
    local log="$2"
    local log_path="$(dirname "$LOGFILE")"
    [ -d "$log_path" ] || mkdir -p "$log_path"
    echo "$log" >> "$LOGFILE"
}

# Log your command before executing it
LOG_RUN() {
    local cmd="$1"
    local level="${2:-DEBUG}"

    $level "$cmd"

	/bin/bash -c "LANG=C LC_ALL=C ${cmd}"
}