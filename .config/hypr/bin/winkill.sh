#!/usr/bin/bash

# |>----|>----|>----|><-><|----<|----<|----<|
# |>    from Klapptnot's Hyprland setup    <|
# |>   https://github.com/Klapptnot/dotf   <|
# |>----|>----|>----|><-><|----<|----<|----<|

# Force kill current window or all windows but current
# Inspired on
# https://www.reddit.com/r/hyprland/comments/1eg4yi8/share_your_kill_all_window_but_current_in_current/
# The commands shared on this post will kill all windows from the same PID
# So, this closes windows and processes

function main {
  # Set IFS to split on hyphen, dot, or space
  IFS='-. _' read -r what who <<< "${*}"

  if check_swap "${what}" "${who:=none}"; then
    local tmp="${what}"
    what="${who}"
    who="${tmp}"
  fi
  unset tmp

  if ! check_args "${what}" "${who}"; then
    handle_incorrect_args "${what:-none}" "${who:-none}"
  fi

  case "${what}" in
    'kill') kill_windows "${who}" ;;
    'close') close_windows "${who}" ;;
  esac
}

function check_swap {
  case "${1}" in
    "current" | "others") return 0 ;;
  esac
  case "${2}" in
    "kill" | "close") return 0 ;;
  esac
  return 1
}

function check_args {
  case "${1}" in
    "kill" | "close");;
    *) return 1 ;;
  esac
  case "${2}" in
    "current" | "others");;
    *) return 1 ;;
  esac
}

function handle_incorrect_args {
  local msg=''

  if [[ "${1}|${2}" == 'none|none' ]]; then
    msg='Missing arguments for operation'
  elif [[ "${1}" == 'none' ]]; then
    msg="Missing operation: ${1}"
  elif [[ "${2}" == 'none' ]]; then
    msg="Missing argument for operation: ${1}"
  elif [[ "${1}" != 'kill' && "${1}" != 'close' ]]; then
    msg="Invalid operation: ${1}"
  elif [[ "${2}" != 'current' && "${2}" != 'others' ]]; then
    msg="Invalid target: ${2}"
  fi

  if [[ -n "${msg}" ]]; then
    printf '\x1b[31m%s\x1b[0m\n' "${msg}" >&2
    printf 'Usage: winkill [kill|close] [current|others]\n'
    exit 1
  fi
}

function close_windows {
  local opr='!='
  [[ "${1}" == 'current' ]] && opr='=='

  jq -rM --null-input \
    --argjson c "$(hyprctl clients -j)" \
    --argjson w "$(hyprctl activeworkspace -j)" \
    '$c[] | select(.workspace.id == $w.id) | select(.focusHistoryID '"${opr}"' 0) | "address:" + .address' |
    xargs --no-run-if-empty --max-args 1 hyprctl dispatch closewindow
}

function kill_windows {
  local opr='!='
  [[ "${1}" == 'current' ]] && opr='=='

  jq -rM --null-input \
    --argjson c "$(hyprctl clients -j)" \
    --argjson w "$(hyprctl activeworkspace -j)" \
    '$c[] | select(.workspace.id == $w.id) | select(.focusHistoryID '"${opr}"' 0) | .pid' |
    xargs --no-run-if-empty kill
}

main "${@}"
