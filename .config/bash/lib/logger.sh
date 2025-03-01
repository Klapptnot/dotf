#!/usr/bin/bash

declare -rA LOGGER_LOG_COLORS=(
  ['d']='\x1b[32m'
  ['i']='\x1b[34m'
  ['w']='\x1b[33m'
  ['e']='\x1b[31m'
  ['c']='\x1b[30m\x1b[41m'
)
declare -rA LOGGER_LEVEL_NAMES=(
  ['o']='off'      # 0
  ['d']='debug'    # 1
  ['i']='info'     # 2
  ['w']='warn'     # 3
  ['e']='error'    # 4
  ['c']='critical' # 5
)
declare -rA LOGGER_LEVEL_NUMS=(
  ['o']="0"
  ['d']="1"
  ['i']="2"
  ['w']="3"
  ['e']="4"
  ['c']="5"
)

LOGGER_LEVEL="${LOGGER_LEVEL:-i}"

# Print (or not) to output info based on the LOGGER_LEVEL env var
# LOGGER_LEVEL is set to `i` by default
# Usage:
#   log <level> <fmt> [args...]
# Example:
#   $ some_fun_or_script() {
#   >   log d 'Given %d params' ${#}
#   >  }
#   $
#   $ some_fun_or_script a b c d # does not print
#   $ LOGGER_LEVEL=d some_fun_or_script a b c d # prints the info
#   Given 4 params
function log {
  local level="${1,,}"
  local show_verbose_info=true
  ((${#level} > 1)) && show_verbose_info=false
  level="${level:0:1}"
  : "${LOGGER_LEVEL:-e}"
  local log_level="${LOGGER_LEVEL_NUMS[${_:0:1}]}"
  local log_id="${LOGGER_LEVEL_NUMS[${level}]}"
  local format="${2}"
  shift 2

  if ((0 == log_level)) || ((log_id < log_level)); then
    return
  fi

  local color="${LOGGER_LOG_COLORS[${level}]}"
  test -z "${color}" && level="default"
  level="${LOGGER_LEVEL_NAMES[${level}]}"
  test -z "${level}" && level="default"

  # shellcheck disable=SC2059
  printf -v message "${format}" "${@}"

  # Output the log message
  if ${show_verbose_info}; then
    printf '%b%s\x1b[0m\n' "${color}" "${message}"
  else
    printf '%b[%s] %s: %s\x1b[0m\n' "${color}" "$(date +%Y-%m-%d_%H:%M:%S)" "${level^^}" "${message}"
  fi
}
