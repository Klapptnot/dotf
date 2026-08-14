#!/usr/bin/env bash

function --bcd-menu-select {
  local prompt="${1}"
  shift
  local options=("${@}")
  local count="${#options[@]}"
  local idx=0
  local key

  trap 'printf "\x1b[?25h"; unset -f __menu_draw; trap - INT TERM ; return 130' INT
  trap 'printf "\x1b[?25h"; unset -f __menu_draw; trap - INT TERM ; return' TERM

  function __menu_draw {
    local i
    for ((i = 0; i < count; i++)); do
      if ((i == idx)); then
        printf '\x1b[38;5;255m➜  %s  \x1b[0m\n' "${options[i]}"
      else
        printf '\x1b[38;5;249m   %s  \x1b[0m\n' "${options[i]}"
      fi
    done
  }

  printf '\x1b[?25l%s' "${prompt:+${prompt}$'\n'}"
  __menu_draw

  while true; do
    IFS= read -t 10 -rsn1 key
    if [[ "${key}" == $'\x1b' ]]; then
      read -rsn2 key # swallow the rest of the escape seq
      case "${key}" in
        '[A') ((idx = (idx - 1 + count) % count)) ;; # up
        '[B') ((idx = (idx + 1) % count)) ;;         # down
      esac
    elif [[ -z "${key}" ]]; then
      [[ -n "${prompt}" ]] && ((count++))
      printf '\x1b[%dA\x1b[0G\x1b[0J' "${count}"
      break
    fi
    printf '\x1b[%dA' "${count}" # cursor up N lines, then redraw in place
    __menu_draw
  done

  printf '\x1b[?25h'
  unset -f __menu_draw
  trap - INT TERM
  REPLY="${idx}"
  MENU_CHOICE="${options[idx]}"
}

function cd {
  local -
  shopt -s nullglob

  if ((${#} == 0)); then
    command cd
    return
  fi

  local REPLY=0 MENU_CHOICE=''
  case "${1}" in
    -)
      local options=()
      local pattern=''
      local idx=1
      while [[ "${!idx}" == '-' ]]; do
        pattern+='*/'
        ((idx++))
      done
      local IFS=/
      pattern+="${*:idx}"
      compgen -V options -G "${pattern}/"

      REPLY=0
      MENU_CHOICE="${options[0]}"
      ((${#options[@]} > 1)) && --bcd-menu-select 'Select directory:' "${options[@]}"
      if ((${#options[@]} == 0));then
        IFS=' '
        printf 'no match: %s\n' "${*}" >&2
        return 1
      fi
      ;;
    ..*)
      MENU_CHOICE="../"
      local whl_path="${1:2}"
      while [[ "${whl_path:0:1}" == '.' ]]; do
        MENU_CHOICE+='../'
        whl_path="${whl_path:1}"
      done
      [[ -n "${whl_path}" ]] && MENU_CHOICE+="/${whl_path#/}"
      local IFS=/
      MENU_CHOICE+="/${*:2}"
      ;;
    *)
      local IFS=/
      MENU_CHOICE+="${*}"
      ;;
  esac

  command cd -- "${MENU_CHOICE}"
}
