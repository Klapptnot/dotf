#!/usr/bin/bash

# Barg - Bash ARGuments parser
# ============================
#
# BETA - Functional but with known limitations:
# - Logical operators (|| &&) follow bash (ambiguous) behavior

# Check if this script is being executed as the main script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Break execution
  printf "[\x1b[38;05;160m*\x1b[00m] This script is not made to run as a normal script\n"
  exit 1
fi

# Parse command line arguments based on a
# special definition syntax
# Usage:
#   barg.parse "<command_line>" <<< "${definitions}"
# Example:
# This will have 3 subcommands, and will require
# positional arguments for `echo`, and for `help` and `echo`
# will have flags (true/false)
# For `tell` will have required (note the `!`) parameters
# ```bash
#   barg.parse "${argv[@]}" <<EOF
#     #[progname='Example']
#     #[subcmds='help tell *echo', subcmdr='true']
#     #[reqextras='true', extras='PARAMS']
#
#     @help a/all[bool] => HELP_SHOW_ALL
#     @tell ! r/receiver[str] => TELL_MESSAGE_RECEIVER
#     @tell ! m/message[str] => TELL_MESSAGE
#
#     @echo n/no-lf[bool] => ECHO_NO_LINEFEED
#
#     @ v/verbose[bool] => MAIN_VERBOSE
#   EOF
# ```
function barg.parse {
  [ "${#}" -eq 0 ] && return 1
  read -r _ extglob_s < <(shopt extglob)
  read -r _ patsub_replacement_s < <(shopt patsub_replacement)
  [ "${extglob_s}" == 'off' ] && shopt -s extglob
  [ "${patsub_replacement_s}" == 'off' ] && shopt -s patsub_replacement
  function barg.var_exists {
    declare -p "${1}" &> /dev/null
  }
  function barg.is_in_arr {
    # This works with shopt -s extglob
    local arr=("${@:2}")
    printf -v t '%s' "${arr[@]/#!("${1}")/}"
    test "${#t}" -gt 0
  }
  # Expand the joint arguments
  function barg.normalize_args {
    for ((i = 0; i < ${#argv[@]}; i++)); do
      if [[ "${argv[i]}" != -* ]] || [ "${#argv[i]}" -eq 2 ] || [[ "${argv[i]}" == --* ]]; then
        continue
      fi
      if [[ "${argv[i]}" =~ ^-[A-Za-z][0-9_\.]*$ ]]; then # only -t2 (argument and numeric value)
        argv=(
          "${argv[@]:0:i}"           # All before joint argument
          "${argv[i]:0:2}"           # the short argument key
          "${argv[i]:2:${#argv[i]}}" # The content of the argument
          "${argv[@]:(i + 1)}"       # All after joint argument
        )
      else
        argv[i]="${argv[i]:1}"
        # This works with `shopt -s patsub_replacement`
        read -ra __slices__ <<< "${argv[i]//?/-&\ }"
        if [[ "${#__slices__[@]}" -gt 0 ]]; then
          argv=(
            "${argv[@]:0:i}"     # All before joint argument
            "${__slices__[@]}"   # All individual argument
            "${argv[@]:(i + 1)}" # All after joint argument
          )
        fi
        unset __slices__
      fi
    done
  }

  function barg.set_indices_to_empty {
    for index in "${@}"; do
      if ((index >= 0 && index < ${#BARG_EXTRAS_BEFORE[@]})); then
        # shellcheck disable=SC2323
        [ "${BARG_EXTRAS_BEFORE[index]}" == '--' ] && BARG_EXTRAS_BEFORE[(index + 1)]=""
        BARG_EXTRAS_BEFORE[index]=""
      fi
    done
  }

  # barg.define "${arg_pat}" "${var_name}" "${def_val}" "${arg_type}" "${vec_type}" "${switch_pat}" "${__ignore__}"
  function barg.define {
    local __pat__="${1}" # short/long[...]
    local __var__="${2}" # VARIABLE (variable name)
    local __val__="${3}" # Variable default value
    local __typ__="${4}" # Variable value type
    local __vec__="${5}" # Vector variable value type
    local __swi__="${6}" # Switch Pattern
    local __lst__="${7}" # List
    local __ign__="${8}" # Ignore command line value and set default if available

    local check_valid_item=false
    if [ -n "${__swi__}" ]; then
      local STR="${__swi__}"
      while [[ "${STR}" =~ ${__swi_regex__} ]]; do
        local short="-${BASH_REMATCH[2]}"
        local long="--${BASH_REMATCH[3]}"
        local value="${BASH_REMATCH[5]:-${BASH_REMATCH[7]}}"

        if barg.is_in_arr "${short}" "${!_argv_table[@]}"; then
          ! barg.var_exists "${__var__}" && declare -g "${__var__}=${value}"
          barg.set_indices_to_empty $((${_argv_table["${short}"]} - 1))
          unset "_argv_table[${short}]"
        elif barg.is_in_arr "${long}" "${!_argv_table[@]}"; then
          ! barg.var_exists "${__var__}" && declare -g "${__var__}=${value}"
          barg.set_indices_to_empty $((${_argv_table["${long}"]} - 1))
          unset "_argv_table[${long}]"
        fi

        STR="${STR/#"${BASH_REMATCH[0]}"/}"
      done
      if ! ${__ign__} && barg.var_exists "${__var__}"; then
        return 0
      fi
      declare -g "${__var__}=${__val__:-0}"
      return 2
    elif [ -n "${__lst__}" ]; then
      check_valid_item=true
      local STR="${__lst__}"
      __pat__="${__pat__%%\ *}[str]"
      __typ__='str'
      local __valid_items__=()
      while [[ "${STR}" =~ ${__lst_regex__} ]]; do
        local value="${BASH_REMATCH[2]:-${BASH_REMATCH[4]}}"
        __valid_items__+=("${value}")
        STR="${STR/#"${BASH_REMATCH[0]}"/}"
      done
      __val__="${__valid_items__[0]}"
    fi

    #shellcheck disable=2178
    local __key__="${__pat__%%[*}"
    local __short__="${__key__%/*}"
    local __long__="${__key__#*/}"

    # Check if it was found in command line and set its
    # form for the key of the args table, otherwise set default
    if [ -n "${_argv_table["-${__short__}"]}" ]; then
      local _table_item="-${__short__}"
    elif [ -n "${_argv_table["--${__long__}"]}" ]; then
      local _table_item="--${__long__}"
    else
      if [ "${__typ__}" == "bool" ]; then
        declare -g "${__var__}=false"
      elif [ -n "${__vec__}" ]; then
        declare -ag "${__var__}=()"
      else
        declare -g "${__var__}=${__val__}"
      fi
      return 1
    fi

    local __rm_arg__=true
    case "${__typ__}" in
      'bool')
        ! barg.var_exists "${__var__}" && declare -g "${__var__}=true"
        barg.set_indices_to_empty $((${_argv_table[${_table_item}]} - 1))
        unset "_argv_table[${_table_item}]"
        __rm_arg__=false
        ;;
      'vec'*)
        local _current_indexes=()
        IFS=',' read -ra _current_indexes <<< "${_argv_table[${_table_item}]}"
        for index in "${_current_indexes[@]}"; do
          [ -z "${argv[index]}" ] && continue
          if [ "${__vec__}" == "num" ] && ! [[ "${argv[index]}" =~ ${__num_regex__} ]]; then # Not an valid num...
            if [[ "${argv[index]}" =~ ^[_\.0-9]*$ ]]; then                                   # but could be a num?
              barg.exit "Unknown format" "Invalid numerical value, expected a int or float (${argv[index]})" 15
            fi
            barg.exit "Type mismatch" "Expected int or float, got string (${argv[index]})" 14
          elif [ "${__vec__}" == "int" ] && ! [[ "${argv[index]}" =~ ${__int_regex__} ]]; then # Not an valid int...
            if [[ "${argv[index]}" =~ ^[_\.0-9]*$ ]]; then                                     # but could be a int?
              barg.exit "Unknown format" "Invalid numerical value, expected a integer (${argv[index]})" 15
            fi
            barg.exit "Type mismatch" "Expected int, got string (${argv[index]})" 14
          elif [ "${__vec__}" == "float" ] && ! [[ "${argv[index]}" =~ ${__flt_regex__} ]]; then # Not an valid float...
            if [[ "${argv[index]}" =~ ^[_\.0-9]*$ ]]; then                                       # but could be a float?
              barg.exit "Unknown format" "Invalid numerical value, expected a float (${argv[index]})" 15
            fi
            barg.exit "Type mismatch" "Expected float, got string (${argv[index]})" 14
          fi
          case "${argv[index]}" in
            '--')
              if [ "${__vec__}" == 'str' ]; then
                declare -ga "${__var__}+=(\"${argv[index + 1]}\")"
              else
                declare -ga "${__var__}+=(\"${argv[index + 1]//_/}\")"
              fi
              ;;
            '-'*)
              barg.exit "Param-like value" "Value for '${argv[(index - 1)]}' looks like an option/flag. Use '-- ${argv[index]}' to bypass" 18
              ;;
            *)
              if [ "${__vec__}" == 'str' ]; then
                declare -ga "${__var__}+=(\"${argv[index]}\")"
              else
                declare -ga "${__var__}+=(\"${argv[index]//_/}\")"
              fi
              ;;
          esac
        done
        unset "_current_indexes"
        ;;
      'num')
        if ! [[ "${argv[${_argv_table[${_table_item}]}]}" =~ ${__num_regex__} ]]; then # Not an valid num...
          if [[ "${argv[${_argv_table[${_table_item}]}]}" =~ ^[_\.0-9]*$ ]]; then      # but could be a num?
            barg.exit "Unknown format" "Invalid numerical value, expected a int or float (${argv[${_argv_table[${_table_item}]}]})" 15
          fi
          barg.exit "Type mismatch" "Expected int or float, got string (${argv[${_argv_table[${_table_item}]}]})" 14
        fi
        case "${argv[${_argv_table[${_table_item}]}]}" in
          '--')
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[(${_argv_table[${_table_item}]} + 1)]//_/}"
            ;;
          '-'*)
            barg.exit "Param-like value" "Value for '${argv[(${_argv_table[${_table_item}]} - 1)]}' looks like an option/flag. Use '-- ${argv[${_argv_table[${_table_item}]}]}' to bypass" 18
            ;;
          *)
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[${_argv_table[${_table_item}]}]//_/}"
            ;;
        esac
        ;;
      'int')
        if ! [[ "${argv[${_argv_table[${_table_item}]}]}" =~ ${__int_regex__} ]]; then # Not an valid int...
          if [[ "${argv[${_argv_table[${_table_item}]}]}" =~ ^[_\.0-9]*$ ]]; then      # but could be a int?
            barg.exit "Unknown format" "Invalid numerical value, expected a integer (${argv[${_argv_table[${_table_item}]}]})" 15
          fi
          barg.exit "Type mismatch" "Expected int, got string (${argv[${_argv_table[${_table_item}]}]})" 14
        fi
        case "${argv[${_argv_table[${_table_item}]}]}" in
          '--')
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[(${_argv_table[${_table_item}]} + 1)]//_/}"
            ;;
          '-'*)
            barg.exit "Param-like value" "Value for '${argv[(${_argv_table[${_table_item}]} - 1)]}' looks like an option/flag. Use '-- ${argv[${_argv_table[${_table_item}]}]}' to bypass" 18
            ;;
          *)
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[${_argv_table[${_table_item}]}]//_/}"
            ;;
        esac
        ;;
      'float')
        if ! [[ "${argv[${_argv_table[${_table_item}]}]}" =~ ${__flt_regex__} ]]; then # Not an valid float...
          if [[ "${argv[${_argv_table[${_table_item}]}]}" =~ ^[_\.0-9]*$ ]]; then      # but could be a float?
            barg.exit "Unknown format" "Invalid numerical value, expected a float (${argv[${_argv_table[${_table_item}]}]})" 15
          fi
          barg.exit "Type mismatch" "Expected float, got string (${argv[${_argv_table[${_table_item}]}]})" 14
        fi
        case "${argv[${_argv_table[${_table_item}]}]}" in
          '--')
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[(${_argv_table[${_table_item}]} + 1)]//_/}"
            ;;
          '-'*)
            barg.exit "Param-like value" "Value for '${argv[(${_argv_table[${_table_item}]} - 1)]}' looks like an option/flag. Use '-- ${argv[${_argv_table[${_table_item}]}]}' to bypass" 18
            ;;
          *)
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[${_argv_table[${_table_item}]}]//_/}"
            ;;
        esac
        ;;
      'str')
        case "${argv[${_argv_table[${_table_item}]}]}" in
          '--')
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[(${_argv_table[${_table_item}]} + 1)]}"
            ;;
          '-'*)
            barg.exit "Param-like value" "Value for '${argv[(${_argv_table[${_table_item}]} - 1)]}' looks like an option/flag. Use '-- ${argv[${_argv_table[${_table_item}]}]}' to bypass" 18
            ;;
          *)
            ! barg.var_exists "${__var__}" && declare -g "${__var__}=${argv[${_argv_table[${_table_item}]}]}"
            ;;
        esac
        ;;
    esac

    # Let items empty in BARG_EXTRAS
    # Not removing them to keep same lenght same index
    if ${__rm_arg__}; then
      local new_idxs=()
      IFS=',' read -ra _current_indexes <<< "${_argv_table[${_table_item}]}"
      for i in "${_current_indexes[@]}"; do
        new_idxs+=("$((i - 1))")
      done
      barg.set_indices_to_empty "${_current_indexes[@]}" "${new_idxs[@]}"
      unset "new_idxs"
      unset "_current_indexes"
      unset "_argv_table[${_table_item}]"
    fi

    if ${check_valid_item}; then
      if barg.var_exists "${__var__}" && ! barg.is_in_arr "${!__var__}" "${__valid_items__[@]}"; then
        printf -v items '%s, ' "${__valid_items__[@]:1}"
        items="${items%,*} or ${__valid_items__[0]}"
        barg.exit "Invalid parameter value" "Argument of \`-${__short__}/--${__long__}\` must be between: ${items}" 23
      fi
    fi

    ! ${__ign__} && return 0

    # Set default value if command line was empty
    if [ "${__typ__}" == "bool" ]; then
      declare -g "${__var__}=false"
    elif [ -n "${__vec__}" ]; then
      declare -ag "${__var__}=()"
    else
      declare -g "${__var__}=${__val__}"
    fi
    return 1
  }

  # barg.exit <error type> <error desc> <exit code>
  # shellcheck disable=SC2154
  function barg.exit {
    local ecolor="${__barg_colors[err]}"
    local stderr="${__barg_opts__[stderr]}"
    local output="${__barg_opts__[output]}"
    local errvar="${__barg_opts__[errvar]}"
    local progname="${__barg_opts__[progname]}"
    local exit="${__barg_opts__[exit]}"

    local error_type="${1:-null}"
    local error_desc="${2:-null}"

    local __err__="${ecolor}ERROR: ${progname} -> ${error_type}...\x1b[00m ${error_desc}"

    if [ "${output}" == 'true' ]; then
      [ "${stderr}" == 'true' ] && printf '%b\n' "${__err__}" >&2 ||
        printf '%b\n' "${__err__}"
    fi

    if [ "${errvar:-NULL}" != 'null' ] && [ "${output}" == 'true' ]; then
      declare -g "${errvar}=${error_type}\n${error_desc}\n${3:-null}"
    fi

    local exit_code="${3:-1}"
    # Exit early if error is from options, or return
    if [ "${exit_code}" -lt 20 ] && [ "${exit}" != 'true' ]; then
      return "${exit_code}"
    fi

    exit "${exit_code}"
  }

  # Int or float
  local __num_regex__='^((-?[0-9]{1,3}(_[0-9]{3})*|-?[0-9]*)|(-?[0-9]{1,3}(_[0-9]{3})+\.([0-9]{3}(_[0-9]{1,3})*|[0-9]{1,3})|-?[0-9]+\.[0-9]+))$'
  local __int_regex__='^(-?[0-9]{1,3}(_[0-9]{3})*|-?[0-9]*)$'
  local __flt_regex__='^(-?[0-9]{1,3}(_[0-9]{3})+\.([0-9]{3}(_[0-9]{1,3})*|[0-9]{1,3})|-?[0-9]+\.[0-9]+)$'
  local __opt_regex__='(,|#\[)\ *([A-Za-z_][_A-Za-z0-9]+?)=|"(([^"\\]|\\.)*)"\]?|'\''(([^'\''\\]|\\.)*)'\''\]?'
  # shellcheck disable=SC1003
  local __def_regex__='\s*(\|\||&&|<>)?\s*(!)?\s*(@[a-zA-Z0-9\-_]*)?\s*([A-Za-z0-9!?@#_.:<>]?/?[A-Za-z0-9!?@#_.:<>\-]+\[(str|float|int|num|bool|vec\[(str|float|int|num|bool)\])\]|\{((\s*[A-Za-z0-9!?@#_.:<>]?/?[A-Za-z0-9!?@#_.:<>\-]+\s*=>\s*("((\\"|[^"])*?)"|'\''((\\'\''|[^'\''])*?)'\'')\s*)+)\}|\s*[A-Za-z0-9!?@#_.:<>]?/?[A-Za-z0-9!?@#_.:<>\-]+\s*\[((\s*\s*("((\\"|[^"])*?)"|'\''((\\'\''|[^'\''])*?)'\'')\s*)+)\])\s*(\|>\s*("((\\"|[^"])*?)"|'\''((\\'\''|[^'\''])*?)'\''))?\s*=>\s*([a-zA-Z][a-zA-Z0-9_]*)' #(\s*("((\\"|[^"])*?)"|'\''((\\'\''|[^'\''])*?)'\''))?'
  # shellcheck disable=SC1003
  local __swi_regex__='\s*(([A-Za-z0-9!?@#_.:<>])/([A-Za-z0-9!?@#_.:<>\-]+)\s*=>\s*("((\\"|[^"])*?)"|'\''((\\'\''|[^'\''])*?)'\''))\s*'
  # shellcheck disable=SC1003
  local __lst_regex__='\s*("((\\"|[^"])*?)"|'\''((\\'\''|[^'\''])*?)'\'')\s*'

  local __line__=1
  declare -A __barg_opts__=(
    [colors]=':'       # Error message color (default: :)
    [output]=true      # Print output to the console (default: true)
    [stderr]=true      # Redirect output to standard error (default: true)
    [exit]=true        # Exit the script on error (instead of returning an error code)
    [reqextras]=false  # Treat positional arguments as required (default: false)
    [subcmdr]=false    # Require a subcommand to be specified (default: false)
    [subcmds]=''       # Space-separated list of valid subcommands (default: empty)
    [emptycheck]=false # Allow required values to be zero-length (default: false)
    [progname]='BARG'  # Program name to use in error messages (default: 'BARG')
    [errvar]=null      # Variable name to store error data in (default: null)
    [extras]=null      # Collect positional parameters (default: null)
  )
  declare -A __barg_colors=(
    [err]=''
    [hil]=''
  )

  local __ilegal_var_names__=(
    BASH BASH_ENV BASH_SUBSHELL BASHPID BASH_VERSINFO BASH_VERSION CDPATH
    DIRSTACK EDITOR EUID FUNCNAME GLOBIGNORE GROUPS HOME HOSTNAME
    HOSTTYPE IFS IGNOREEOF LC_COLLATE LC_CTYPE LINENO MACHTYPE OLDPWD
    OSTYPE PATH PIPESTATUS PPID PROMPT_COMMAND PS1 PS2 PS3 PS4 PWD
    REPLY SECONDS SHELLOPTS SHLVL TMOUT UID
  )

  local STR=""
  while read -r line; do
    # Change the default value for all given options
    if [[ "${line}" == '#['*']' ]]; then
      local __optkey__=""
      local STR="${line}"
      while [[ ${STR} =~ ${__opt_regex__} ]]; do
        if [ -n "${BASH_REMATCH[2]}" ]; then
          __optkey__="${BASH_REMATCH[2]}"
        else
          if [[ " ${!__barg_opts__[*]} " != *" ${__optkey__} "* ]]; then
            barg.exit "Invalid option" "Option '${__optkey__}' does not exist" 20
          fi
          # 3 is single quote, otherwise 5 for double quote
          __barg_opts__[${__optkey__}]="${BASH_REMATCH[3]:-${BASH_REMATCH[5]}}"
        fi
        # Escapes in string must be escaped
        STR="${STR/#"${BASH_REMATCH[0]//\\/\\\\}"/}"
      done
      unset __optkey__
      unset STR
      continue
    fi
    [[ "${line}" == '#'* ]] && continue
    STR+="${line}"$'\n'
  done

  if [ -n "${__barg_opts__[colors]}" ]; then
    [ "${__barg_opts__[colors]}" == ':' ] && __barg_opts__[colors]="38;5;9:38;5;50"
    __barg_colors[err]="\x1b[${__barg_opts__[colors]%:*}m"
    __barg_colors[hil]="\x1b[${__barg_opts__[colors]#*:}m"
  fi

  local argv=("${@}")

  declare -g BARG_SUBCOMMAND=""
  local BARG_SUBCOMMAND_NEEDS_EXTRAS=false
  # Try to get the possible sub command
  if [ -n "${__barg_opts__[subcmds]}" ]; then
    # shellcheck disable=SC2206
    local subcmds=(${__barg_opts__[subcmds]})
    if barg.is_in_arr "${argv[0]}" "${subcmds[@]/#\*/}"; then
      # check if it does not need extras
      [[ " ${__barg_opts__[subcmds]} " == *" *${argv[0]} "* ]] && BARG_SUBCOMMAND_NEEDS_EXTRAS=true
      BARG_SUBCOMMAND="${argv[0]}"
      argv=("${argv[@]:1}")
    fi
  fi
  if [ "${__barg_opts__[subcmdr]}" == "true" ] && [ -n "${__barg_opts__[subcmds]}" ] && [ -z "${BARG_SUBCOMMAND}" ]; then
    # shellcheck disable=SC2206
    local subcmds=(${__barg_opts__[subcmds]})
    subcmds=("${subcmds[@]/#\*/}")
    local subcommands_l="${#subcmds[@]}"
    if ((subcommands_l > 3)); then
      printf -v subcmds '\n  - \x1b[38;5;4m%s\x1b[0m' "${subcmds[@]}"
    else
      printf -v subcmds \
        ' \x1b[38;5;4m%s\x1b[0m, \x1b[38;5;4m%s\x1b[0m, or \x1b[38;5;4m%s\x1b[0m' \
        "${subcmds[0]}" "${subcmds[1]}" "${subcmds[2]}"
    fi
    barg.exit "Missing subcommand" "A subcommand is required, one of:${subcmds}" 21
  fi
  # remove to not add it to extras
  [ "${argv[0]}" == '--' ] && argv=("${argv[@]:1}")

  barg.normalize_args # Normalize joint arguments, from '-abc' to '-a -b -c'
  declare -A _argv_table
  local i=-1
  while ((i < ${#argv[@]})); do
    ((i++))
    # Treating next as a value
    if [[ "${argv[i]}" == '--' ]]; then
      ((i++))
      continue
    elif [[ "${argv[i]}" != -* ]]; then
      continue
    fi

    # If not set, simply add
    if [ -z "${_argv_table[${argv[i]}]}" ]; then
      _argv_table[${argv[i]}]=$((i + 1))
      continue
    fi
    # Append comma separated for vec[any]
    _argv_table[${argv[i]}]="${_argv_table[${argv[i]}]},$((i + 1))"
  done
  unset i
  local BARG_EXTRAS_BEFORE=("${argv[@]}")

  local __ignore__=false
  local __grpsts__=''
  local __status__=''
  local __required__=false
  local last=""
  local __last_sig=""
  local __defer_error=()
  while true; do
    if [[ "${STR}" =~ ${__def_regex__} ]]; then
      STR="${STR/#"${BASH_REMATCH[0]}"/}"
    else
      # If a required has no args, check first if a opr will be used with it
      if [ "${#__defer_error}" -gt 0 ] && [ -z "${log_opr}" ]; then
        barg.exit "${__defer_error[@]}"
      fi
      break
    fi

    if [ "${BASH_REMATCH[0]}" == "${last}" ]; then
      barg.exit "Invalid syntax" "Not able to continue, error before: ${last}" 67
    fi
    last="${BASH_REMATCH[0]}"

    # for i in "${!BASH_REMATCH[@]}"; do printf '%d = %q\n' "${i}" "${BASH_REMATCH[i]}"; done
    local log_opr="${BASH_REMATCH[1]}"    # ?-> Operation (||, &&, <>)
    local arg_lvl="${BASH_REMATCH[2]}"    # ?-> Is required?????
    local arg_par="${BASH_REMATCH[3]}"    # ?-> Arg father (sub command)
    local arg_pat="${BASH_REMATCH[4]}"    # |-> Pattern
    local arg_type="${BASH_REMATCH[5]}"   # |-> Data type
    local vec_type="${BASH_REMATCH[6]}"   # ?-> Vec of
    local switch_pat="${BASH_REMATCH[7]}" # ?-> Switch
    local list_pat="${BASH_REMATCH[14]}"  # ?-> List
    # added 7 to each index
    local def_val="${BASH_REMATCH[23]:-${BASH_REMATCH[25]}}" # ?-> Default value
    local var_name="${BASH_REMATCH[27]}"                     # |-> Variable name
    # local def_desc="${BASH_REMATCH[30]:-${BASH_REMATCH[32]}}" # ?-> Def description

    [[ -n "${log_opr}" && -n "${subcmd_prop}" ]] && arg_par="@${subcmd_prop}"
    [[ -n "${log_opr}" && "${__required__}" == 'true' ]] && arg_lvl='!'

    # If it's only `@`, the param is for the use without subcommand
    ((${#BARG_SUBCOMMAND} > 0)) && ((${#arg_par} == 1)) && continue

    local subcmd_prop="${arg_par:1}"
    # skip options for a distinct sub command
    if [ -n "${subcmd_prop}" ] && [ "${subcmd_prop}" != "${BARG_SUBCOMMAND}" ]; then
      continue
    fi

    # If a req has no args, check first if a opr will be used with it
    if [ "${#__defer_error}" -gt 0 ] && [ -z "${log_opr}" ]; then
      barg.exit "${__defer_error[@]}"
    fi
    __defer_error=()

    [ "${arg_lvl}" == "!" ] && __required__=true || __required__=false

    if barg.is_in_arr "${var_name}" "${__ilegal_var_names__[@]}"; then
      barg.exit "Ilegal variable name" "${var_name} is a reserved variable name." 78
    fi

    if [ "${log_opr}" == "<>" ]; then
      if [ -z "${__status__}" ]; then
        barg.exit "Ilegal operation" "The <> was used without a left definition" 43
      fi
      if [ -z "${__grpsts__}" ]; then
        __grpsts__=${__status__}
      fi
      ${__grpsts__} && __ignore__=false || __ignore__=true
    else
      __ignore__=false
      __grpsts__=''
    fi

    if [[ "${vec_type}" == "vec[bool]" ]]; then
      barg.exit "Invalid data type" "A vector of bool is not a valid data type" 17
    fi

    local def_set=false
    local last_run=false
    # shellcheck disable=SC2015
    if barg.define "${arg_pat}" "${var_name}" "${def_val}" "${arg_type}" "${vec_type}" "${switch_pat}" "${list_pat}" "${__ignore__}"; then
      last_run=true
    else
      ((${#def_val} > 0)) && def_set=true
    fi

    # Default values are not useful in required
    # Default value of the default value is ""
    # restore the not set status
    if ${__required__} && ! ${last_run}; then
      def_set=false
      unset "${var_name}"
    fi

    # Is empty but was defined
    ${__barg_opts__[emptycheck]} && [ "${!var_name@A}" == "${var_name}=''" ] && last_run=false

    #shellcheck disable=2178
    if [[ "${arg_pat}" != "{"*"}" ]]; then
      local _na="${arg_pat%%[*}"
      if [ "${_na%/*}" == "${_na#*/}" ]; then
        local signat="${__barg_colors[hil]}--${_na#*/}\x1b[0m"
      else
        local signat="${__barg_colors[hil]}-${_na%/*}\x1b[0m/${__barg_colors[hil]}--${_na#*/}\x1b[0m"
      fi
    else
      signat="${__barg_colors[hil]}{...switch<${var_name}>}\x1b[0m"
    fi

    if [ -n "${__status__}" ]; then
      if ${__required__}; then
        if [ "${log_opr}" == "&&" ]; then
          if ! ${__status__} && ! ${last_run}; then
            barg.exit "Missing required arguments" "${signat} and ${__last_sig} are mutually required" 111
          elif ! ${__status__} || ! ${last_run}; then
            barg.exit "Failed AND operation" "${signat} requires ${__last_sig}" 111
          fi
        elif [ "${log_opr}" == "||" ]; then
          if ${__status__} && ${last_run}; then
            ${def_set} && continue
            barg.exit "Failed OR operation" "${signat} is not compatible with ${__last_sig}" 112
          elif ! ${__status__} && ! ${last_run}; then
            ${def_set} && continue
            barg.exit "Failed OR operation" "One of ${signat} OR ${__last_sig} is required" 113
          fi
        elif ! barg.var_exists "${var_name}"; then
          __defer_error=("Missing required arguments" "${signat} is a required argument" 113)
        fi
      else
        if [ "${log_opr}" == "&&" ]; then
          if ! ${__status__} || ! ${last_run}; then
            barg.exit "Failed AND operation" "${signat} requires ${__last_sig}" 111
          fi
        elif [ "${log_opr}" == "||" ]; then
          if ${__status__} && ${last_run}; then
            ${def_set} && continue
            barg.exit "Failed OR operation" "${signat} is not compatible with ${__last_sig}" 112
          fi
        fi
      fi
    elif ! barg.var_exists "${var_name}"; then
      if ${__required__} && ! ${last_run}; then
        __defer_error=("Missing required arguments" "${signat} is a required argument" 113)
      fi
    fi

    __status__=${last_run}
    __last_sig="${signat}"
  done

  # String that is non-zero lenght after being striped
  # should mean that regex was not able to match...
  # because it's not available and not because the user made some mistakes
  if [ -n "${STR}" ]; then
    STR="${STR//$'\n'/}"
    STR="${STR//\ /}"
    if [ -n "${STR}" ]; then
      barg.exit "Regex error" "LIBC regex support: GLIBC required" 2
    fi
  fi

  local extras_count=0
  local extras_var_name="${__barg_opts__[extras]}"
  for item in "${BARG_EXTRAS_BEFORE[@]}"; do
    if [[ -n "${item}" ]]; then
      declare -ag "${extras_var_name}+=(\"${item//\"/\\\"}\")"
      ((extras_count++))
    fi
  done

  # shellcheck disable=SC2034
  declare -g "${extras_var_name}_COUNT"="${extras_count}"

  if ${__barg_opts__[reqextras]} && ((extras_count < 1)); then
    if [ -z "${BARG_SUBCOMMAND}" ] || ${BARG_SUBCOMMAND_NEEDS_EXTRAS}; then
      barg.exit "Missing arguments" "positional arguments are required" 120
    fi
  fi
  unset -f barg.var_exists barg.is_in_arr barg.normalize_args barg.set_indices_to_empty barg.define barg.exit
  [ "${extglob_s}" == 'off' ] && shopt -u extglob
  [ "${patsub_replacement_s}" == 'off' ] && shopt -u patsub_replacement
  return 0
}
