#!/usr/bin/bash
# 🔗 https://github.com/klapptnot/dotf

function file-exists [[ -f "${1:?missing path}" ]]
function is-executable [[ -f "${1:?missing path}" && -x "${1}" ]]
function is-defined [[ -v "${1:?missing var name}" ]]
function as-lines { IFS=$'\n' read -d '' -ra "${1}" || true; }

function fuzzy-get-files {
  tv \
    --source-command "${FIND_FILE_COMMAND:?env var is not declared}" \
    --cache-preview \
    --select-1 \
    --preview-command "bat --style=numbers --color=always --line-range=:500 '{}'" \
    --preview-size 65 \
    --preview-border rounded \
    --preview-word-wrap \
    --input-position top \
    --results-border rounded \
    --input-border rounded \
    --layout landscape \
    --hide-help-panel \
    --hide-status-bar
}

function --nvim-open-files-fuzzy {
  local -a files
  as-lines files < <(fuzzy-get-files)
  ((${#files[@]})) || return
  nvim -- "${files[@]}"
}

function print-path {
  printf '%s\n' "${PATH//:/$'\n'}"
}

function serve-http {
  python -m http.server "${@}"
}

function get-ip {
  curl -Ssl ifconfig.me
}

function which {
  local htap_dmc
  read -r htap_dmc < <(command -v "${1}" 2> /dev/null) || return 2
  is-executable "${htap_dmc}" || return 1
  printf '%s\n' "${htap_dmc}"
}

function set-env {
  declare -x "${1:?missing var name}=${2:-}" 2> /dev/null
}

function pwd-truncated {
  local trunc_pwd='\w'
  trunc_pwd="${trunc_pwd@P}"
  if [[ "${trunc_pwd}" != '/' ]]; then
    trunc_pwd="${trunc_pwd//\/*([!\/])?(\/)/\/&\/}"
    trunc_pwd="${trunc_pwd//\/\/?(...|.?|?)/\/&\/\/}"
    trunc_pwd="${trunc_pwd//\/\/\/\/\//\/}"
    trunc_pwd="${trunc_pwd//\/\/*([!\/])\/\/\//\/}"
    trunc_pwd="${trunc_pwd//\/\//}"
    trunc_pwd="${trunc_pwd%/}"
  fi
  printf '%s' "${trunc_pwd}"
}

function clear { printf '\x1b[0H\x1b[0m\x1b[2J\x1b[3J'; }
