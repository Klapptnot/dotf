#!/usr/bin/bash

declare -g _barg_completion_term_size="${LINES}:${COLUMNS}"
declare -gi _barg_completion_lword_len=-1
declare -gi _barg_completion_saved_row=0
declare -gi _barg_completion_saved_col=0

function _barg_completion_generic {
  local read_point=0
  local scomp_line="${COMP_LINE}"
  local comp_line_len="${#COMP_LINE}"
  local words=()

  for w in "${COMP_WORDS[@]}"; do
    scomp_line="${scomp_line:${#w}}"
    read_point="$((comp_line_len - ${#scomp_line}))"
    scomp_line="${scomp_line#"${scomp_line%%[![:space:]]*}"}"
    if ((read_point > COMP_POINT)); then
      ((COMP_POINT - read_point < 0)) && words+=("${w:0:COMP_POINT - read_point}")
      break
    fi
    words+=("${w}")
    ((read_point == COMP_POINT)) && break
  done

  local command="${words[0]}"
  local lastw="${words[-1]}"

  if [[ "${LINES}:${COLUMNS}" != "${_barg_completion_term_size}" ]]; then
    _barg_completion_lword_len=-1
    _barg_completion_term_size="${LINES}:${COLUMNS}"
  fi

  # TSV output: <value>\t<color>\t<desc>
  mapfile -t original < <("${command}" @tsvcomp "${words[@]}")
  local total="${#original[@]}"

  local row=0 col=0
  IFS='[;' read -p $'\x1b[6n' -t 0.1 -d R -rs _ row col

  # prevents predicted prompt position from being a negative number
  ((total >= LINES)) && {
    ((total = LINES - 1))
    original=("${original[@]:0:total}")
  }
  mapfile -t COMPREPLY < <(printf '%s\n' "${original[@]}" | column -t -s $'\t')

  # Bash (readline) doesn't support descriptions natively
  # Keep full TSV line until selected, then extract just the value
  if ((total == 1)); then
    if [ -n "${COMPREPLY[0]}" ]; then
      local completion="${original[0]%%$'\t'*}"
      COMPREPLY=("${completion}")

      # only restore if autompletions have been shown, which means
      # prompt moved and we can go back, and clean up... unless clear command was issued
      if ((_barg_completion_lword_len != -1 && _barg_completion_saved_row < row)); then
        printf '\x1b[%d;%dH\x1b[0J' "${_barg_completion_saved_row}" "${_barg_completion_saved_col}"
        # seems restoring at a point where completion is saved mid-word
        # means it would get inserted at the end after restoring
        # for that, go back, but print word to restore original position
        ((_barg_completion_lword_len)) \
          && printf '\x1b[%dD%s' "${_barg_completion_lword_len}" "${lastw}" \
          || printf '%s' "${lastw}"
      fi
      _barg_completion_lword_len=-1
    else
      COMPREPLY=()
      # reset after unsuccessful autocompletion, so next time it will
      # save cursor position again
      _barg_completion_lword_len=-1
    fi
  elif ((total > 1)); then
    # only will save position when autocompletion transaction is started
    # and is enough space to show all the items, if not enough space, delay it
    if ((_barg_completion_lword_len == -1)) || ((_barg_completion_lword_len != ${#lastw})); then
      if (((LINES - row) >= total)); then
        # if enough space for all completions, prompt stays in the same line
        _barg_completion_saved_row=${row}
        _barg_completion_saved_col=${col}
      else
        # otherwise predict where the prompt will be after being shifted
        # obviously this is wrong there are more items than lines
        _barg_completion_saved_row=$((row - (total - (LINES - row) + 1)))
        _barg_completion_saved_col=${col}
      fi
    elif ((_barg_completion_saved_row < row)); then
      printf '\x1b[%d;%dH\x1b[0J' "${_barg_completion_saved_row}" "${_barg_completion_saved_col}"
    fi
    _barg_completion_lword_len="${#lastw}"
  fi
}

mapfile -t __files < ~/.config/.bargcomp.yaml
[ -n "${__files[0]}" ] && complete -F _barg_completion_generic "${__files[@]#-\ }"
unset __files
