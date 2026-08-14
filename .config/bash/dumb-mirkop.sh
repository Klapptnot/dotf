#!/usr/bin/bash
# 🔗 https://github.com/klapptnot/dotf

declare -gr MIRKOP_FIELD_REGEX='\{(\{?[^}%]*\}?)\}'
declare -gA MIRKOP_STYLES=()
declare -gA MIRKOP_MODULES=()

declare -g MIRKOP_PS1=''
declare -g MIRKOP_PS2=''
declare -g MIRKOP_PST=''
declare -g MIRKOP_PSR=''
declare -g MIRKOP_PSH=''
declare -gi MIRKOP_PSR_FLEN=0
declare -gi MIRKOP_PST_FLEN=0
declare -gi MIRKOP_PSH_FLEN=0
declare -ga MIRKOP_PS1_MODS=()
declare -ga MIRKOP_PS2_MODS=()
declare -ga MIRKOP_PST_MODS=()
declare -ga MIRKOP_PSR_MODS=()
declare -ga MIRKOP_PSH_MODS=()

declare -gi MIRKOP_HAS_PS2=0
declare -gi MIRKOP_HAS_PSR=0
declare -gi MIRKOP_HAS_PST=0
declare -gi MIRKOP_HAS_PSH=0

declare -g MIRKOP_PST_FMT='\x1b[A\x1b[0G\x1b[0K%s'
declare -g MIRKOP_PSH_FMT='\x1b[%dC%s\n'
declare -g MIRKOP_LOCALITY='local'

declare -g MIRKOP_LAST_PWDF=''
declare -g MIRKOP_LAST_PWDS=''
declare -g MIRKOP_CMD_TIME=''
declare -g MIRKOP_PS1_TIME=''
declare -g MIRKOP_READLINE_LINE=''
declare -g MIRKOP_CMD_DURATION='--'
declare -gi MIRKOP_CHROMAHASH_MASK=0xf0256a
declare -gi MIRKOP_ALLOW_PST=0
declare -gi MIRKOP_LAST_STATUS=0
declare -gi MIRKOP_CMD_ISSPACE=0

function --mirkop-set-title {
  printf '\x1b]0;%s\x07' "${1:?no title?}"
} 2> /dev/null

function --mirkop-cursor-position {
  IFS='[;' read -p $'\e[6n' -d R -rs _ "${1:-CURSOR_ROW}" "${2:-CURSOR_COL}"
}

function --mirkop-style-from-map {
  yaml::is map "${1:?missing map}" || return
  local -n map="${1}"
  local out="${2:?missing out var}"

  local codes=()
  local code s r g b w

  local fg="${map[fg]:-}"
  case "${fg}" in
    ch:light) codes+=('38;2;$0') ;;
    ch:dark) codes+=('38;2;$1') ;;
    *)
      if [[ ${fg} =~ ^#([A-Fa-f0-9]{6})$ ]]; then
        s="${BASH_REMATCH[1]}"
        r=$((16#${s:0:2}))
        g=$((16#${s:2:2}))
        b=$((16#${s:4:2}))
        codes+=("38;2;${r};${g};${b}")
      fi
    ;;
  esac

  local bg="${map[bg]:-}"
  case "${bg}" in
    ch:light) codes+=('48;2;$0') ;;
    ch:dark) codes+=('48;2;$1') ;;
    *)
      if [[ ${bg} =~ ^#([A-Fa-f0-9]{6})$ ]]; then
        s="${BASH_REMATCH[1]}"
        r=$((16#${s:0:2}))
        g=$((16#${s:2:2}))
        b=$((16#${s:4:2}))
        codes+=("48;2;${r};${g};${b}")
      fi
    ;;
  esac

  local attr="${map[attr]:-}"
  local -A seen=()

  for w in ${attr}; do
    case ${w} in
      bold | bright) code=1 ;;
      dim | faint) code=2 ;;
      italic) code=3 ;;
      underline) code=4 ;;
      blink) code=5 ;;
      reverse) code=7 ;;
      strike | strikethrough) code=9 ;;
      *) continue ;;
    esac
    [[ -v "seen[${code}]" ]] && continue
    seen["${code}"]=1
    codes+=("${code}")
  done

  ((${#codes[@]} > 0)) && printf -v "${out}" '\x1b[%sm' "${codes[@]}" || printf -v "${out}" ''
}

function --mirkop-chromahash-generate {
  local hex_str="${2//[^a-zA-Z0-9]/}"
  printf -v hex_str '%06x' "$((64#${hex_str:-root} & MIRKOP_CHROMAHASH_MASK))"

  local r=$((16#${hex_str:0:2}))
  local g=$((16#${hex_str:2:2}))
  local b=$((16#${hex_str:4:2}))

  printf -v "${1}[1]" '%d;%d;%d' ${r} ${g} ${b}

  local luminance=$((2126 * r + 7152 * g + 722 * b))
  while ((luminance < 1000000)); do
    ((r = r < 255 ? r + 60 : 255))
    ((g = g < 255 ? g + 60 : 255))
    ((b = b < 255 ? b + 60 : 255))
    luminance=$((2126 * r + 7152 * g + 722 * b))
  done
  ((r = r < 255 ? r : 255))
  ((g = g < 255 ? g : 255))
  ((b = b < 255 ? b : 255))

  printf -v "${1}[0]" '%d;%d;%d' ${r} ${g} ${b}
}

function --mirkop-format-fields {
  local -n __n_fields="${2:?missing out var}"
  local __mcounter __mmatch style color __n_format
  local __iter_fmt="${!1}"
  local __norm_len="${#__iter_fmt}"
  __iter_fmt="${__iter_fmt//%/%%}"
  __norm_len="$((${#__iter_fmt} - __norm_len))"
  __n_fields=()

  while [[ "${__iter_fmt}" =~ ${MIRKOP_FIELD_REGEX} ]]; do
    __mmatch="${BASH_REMATCH[1]}"
    __n_format+="${__iter_fmt%%"${BASH_REMATCH[0]}"*}"
    __iter_fmt="${__iter_fmt#*"${BASH_REMATCH[0]}"}"

    case "${__mmatch}" in
    '{'*|*'}') __n_format+="${__mmatch}" ;;
    '$'*) : "${__mmatch:1}"; __n_format+="${!_}" ;;
    '&') __n_format+=$'\x1b[0m'; ((__norm_len += 4)) ;;
    '&'*)
      style="${MIRKOP_STYLES["${__mmatch:1}"]}"
      if [[ -n "${style}" ]]; then
        if [[ "${style}" =~ \$([01]) ]]; then
          --mirkop-chromahash-generate color "${PWD}"
          style="${style//\$0/"${color[0]}"}"
          style="${style//\$1/"${color[1]}"}"
        fi
        __n_format+="${style}"
        ((__norm_len += ${#style}))
      fi
    ;;
    *)
      __n_fields+=("${__mmatch:-$((__mcounter++))}")
      __n_format+='%s'
      ;;
    esac
  done
  printf -v "${1}" '%s%s' "${__n_format}" "${__iter_fmt}"
  printf -v "${3}" '%d' "$((${#__n_format} - (${#__n_fields[@]} * 2) - __norm_len))"
  return 0
}

function --mirkop-format-fields-ps {
  local -n __n_fields="${2:?missing out var}"
  local __mcounter __mmatch style color __n_format
  local __iter_fmt="${!1//%/%%}"
  __n_fields=()

  while [[ "${__iter_fmt}" =~ ${MIRKOP_FIELD_REGEX} ]]; do
    __mmatch="${BASH_REMATCH[1]}"
    __n_format+="${__iter_fmt%%"${BASH_REMATCH[0]}"*}"
    __iter_fmt="${__iter_fmt#*"${BASH_REMATCH[0]}"}"

    case "${__mmatch}" in
    '{'*|*'}') __n_format+="${__mmatch}" ;;
    '$'*) eval "__n_format+=\${${__mmatch:1}}" ;;
    '&') __n_format+=$'\[\x1b[0m\]' ;;
    '&'*)
      style="${MIRKOP_STYLES["${__mmatch:1}"]}"
      [[ -z "${style}" || "${style}" =~ \$([01]) ]] || __n_format+="\\[${style}\\]"
    ;;
    *)
      __n_fields+=("${__mmatch:-$((__mcounter++))}")
      __n_format+='%s'
      ;;
    esac
  done
  printf -v "${1}" '%s%s' "${__n_format}" "${__iter_fmt}"
  return 0
}

function --mirkop-generate-pwd-short {
  [[ "${MIRKOP_LAST_PWDF}" == "${PWD}" ]] && return
  MIRKOP_LAST_PWDS=''
  case "${PWD}" in
    '/') MIRKOP_LAST_PWDS='/' ;;
    "${HOME}"*)
      MIRKOP_LAST_PWDS='~'
      local s="${PWD#"${HOME}"}"
      [[ -z "${s}" ]] && return
      local -a segs
      IFS='/' read -ra segs <<< "${s:1}"

      local -i i=0 n=${#segs[@]}
      for ((i = 0; i < n - 1; i++)); do
        s="${segs[i]}"
        case "${s}" in
          .*) MIRKOP_LAST_PWDS+="/${s:0:2}" ;;
          *) MIRKOP_LAST_PWDS+="/${s:0:1}" ;;
        esac
      done
      MIRKOP_LAST_PWDS+="/${segs[-1]}"
      ;;
    *) MIRKOP_LAST_PWDS="${PWD}" ;;
  esac
}

function --mirkop-find-markers {
  local __cwd="${PWD}" m
  local -n __found="${1:?missing out var}"

  while :; do
    for m in "${@:2}"; do
      if [[ -e "${__cwd}/${m}" ]]; then
        __found="${__cwd}/${m}"
        return 0
      fi
    done

    [[ -z "${__cwd}" ]] && break
    __cwd=${__cwd%/*}
  done
  __found=''
  return 1
}

function --mirkop-timeit-string {
  local -n __n_ttv0="${1:?missing out var}"
  local start="${2:?missing start time}"
  local end="${3:?missing end time}"

  local start_s=${start%.*}
  local start_us=${start#*.} # `##*.*(0)` to remove line below
  start_us=${start_us#"${start_us%%[!0]*}"}

  local end_s=${end%.*}
  local end_us=${end#*.}
  end_us=${end_us#"${end_us%%[!0]*}"}

  local diff_s=$((end_s - start_s))
  local diff_us=$((diff_s > 0 ? (1000000 + end_us) - start_us : end_us - start_us))
  ((diff_s > 0 && (diff_us >= 1000000 ? diff_us %= 1000000 : diff_s--)))

  local h=$((diff_s / 3600))
  local m=$(((diff_s % 3600) / 60))
  local s=$((diff_s % 60))
  local ms=$((diff_us / 1000))
  local us=$((diff_us % 1000))

  local parts=()
  ((h > 0)) && parts+=("${h}h")
  ((m > 0)) && parts+=("${m}m")
  ((s > 0)) && parts+=("${s}s")
  ((ms > 0 && h == 0)) && parts+=("${ms}ms")
  ((us > 0 && h == 0 && ${#parts[@]} < 3)) && parts+=("${us}us")
  local IFS=''
  __n_ttv0="${parts[*]}"
}

function --mirkop-git-info {
  local branch ahead behind untracked changed conflicted stashed
  read -r branch < <(git branch --show-current 2> /dev/null)
  declare -Ag git_info=(['branch']="${branch}")

  read -r 'git_info[modified]' _ _ 'git_info[inserted]' _ 'git_info[deleted]' _ < <(git diff --shortstat 2> /dev/null)
  read -r ahead behind < <(git rev-list --left-right --count HEAD...@{upstream} 2> /dev/null)

  IFS=$'\n' read -d '' -ra untracked < <(git ls-files --other --exclude-standard 2> /dev/null)
  IFS=$'\n' read -d '' -ra changed < <(git status --porcelain=v1 2> /dev/null)
  IFS=$'\n' read -d '' -ra conflicted < <(git diff --name-only --diff-filter=U)
  IFS=$'\n' read -d '' -ra stashed < <(git stash list)

  git_info[ahead]="${ahead:-0}"
  git_info[behind]="${behind:-0}"
  git_info[untracked]="${#untracked[@]}"
  git_info[changed]="${#changed[@]}"
  git_info[conflicted]="${#conflicted[@]}"
  git_info[stashed]="${#stashed[@]}"
  git_info[staged]="$((git_info[changed] - git_info[modified]))"
  git_info[untracked_dirs]=0

  if ((git_info[untracked] > 0)); then
    IFS=$'\n' read -d '' -ra untracked < <(dirname -- "${untracked[@]}" 2> /dev/null | sort -u)
    git_info[untracked_dirs]="${#untracked[@]}"
  fi
}

function --mirkop-fill-prompt-format {
  local __out_var0="${1}"
  local -i __ff_len0=0
  local __ff_str0="${3:-}"
  local -n __n_mf0="${4:?missing module list}"

  local __recursive_result=''
  [[ -z "${__ff_str0}" ]] && return

  local -a __ff_arr0=()
  declare -p "${__out_var0}" &> /dev/null && __ff_arr0+=(-v "${__out_var0}")
  __ff_arr0+=(-- "${__ff_str0}")
  local __oflen0="${#__ff_arr0[@]}"

  local __ff_val0
  for __ff_val0 in "${__n_mf0[@]}"; do
    --mirkop-parse-format __ff_val0 || __ff_val0=''
    __ff_arr0+=("${__ff_val0}")
  done

  [[ "${2:-_}" != '_' ]] && printf -v "${2}" "${__ff_len0}"
  printf "${__ff_arr0[@]}"
}

function --mirkop-parse-format {
  local format="${!1}"
  local mn found key val mod_fmt_type gir fill num_jobs style
  if [[ -v "MIRKOP_MODULES[${format}]" ]]; then
    local -n cm="${MIRKOP_MODULES["${format}"]}"
    local kind="${cm[kind]:-null}"
    [[ -n "${cm[style]}" ]] && style="${MIRKOP_STYLES["${cm[style]}"]}"

    case "${kind}" in
      locality) format="${cm["${MIRKOP_LOCALITY}"]}" ;;
      date) printf -v format "%(${cm[format]})T" -1 ;;
      battery)
        if [[ ! -v 'POWER_SUPPLY_STATUS' ]]; then
          printf -v found /sys/class/power_supply/BAT?/uevent
          [[ -z "${found}" ]] && return 1
          source "${found}"
        fi
        if [[ "${cm[style_prefix]:-null}" != 'null' ]]; then
          style="${cm[style_prefix]}"
          if [[ "${POWER_SUPPLY_STATUS}" == "Charging" ]]; then
            style+='charging'
          else
            case 1 in
              $((POWER_SUPPLY_CAPACITY <= 15)))  style+='critical' ;;
              $((POWER_SUPPLY_CAPACITY <= 35)))  style+='low' ;;
              $((POWER_SUPPLY_CAPACITY <= 60)))  style+='medium' ;;
              *)                                 style+='healthy' ;;
            esac
          fi
          style="${MIRKOP_STYLES["${style}"]}"
        fi
        ;;&
      env)
        local mfl=0
        yaml::type mfl "${cm[marker]}"
        case "${mfl}" in
          $YAML_STRING) --mirkop-find-markers found "${cm[marker]}" ;;
          $YAML_LIST)
            local -n markers="${cm[marker]}"
            --mirkop-find-markers found "${markers[@]}"
            ;;
        esac

        [[ -z "${found}" ]] && return 1

        if [[ "${cm[exec]:-null}" != 'null' ]]; then
          exec 3< <(bash -s "${found}" <<< "${cm[exec]}")
          case "${cm[parse]}" in
            kv)
              declare -A __mf_out
              while IFS=':= ' read -r key val; do
                [[ -n "${key}" ]] && __mf_out["${key}"]="${val}"
              done <&3
              ;;
            split)
              declare -a __mf_out
              if [[ "${cm[delimiter]:-null}" != 'null' ]]; then
                IFS="${cm[delimiter]@E}" read -ra __mf_out <&3
              else
                read -ra __mf_out <&3
              fi
              ;;
            *)
              declare -a __mf_out
              IFS=$'\n' read -d '' -ra __mf_out <&3
              ;;
          esac

          if ((${#__mf_out[@]} == 0)); then
            printf -v "${1}" ''
            return
          fi
        fi
        ;;&
      git)
        command -v git &> /dev/null || return 1
        --mirkop-find-markers found .git || return 1

        local temp_name="${found//[![:alnum:]]/}${BASHPID}"
        temp_name=$((64#${temp_name}))
        if [[ "${found}/index" -nt "/tmp/mkgm-${temp_name}" ]]; then
          : > "/tmp/mkgm-${temp_name}"
          --mirkop-git-info
        fi
        ;;&
      *) format="${cm[format]}" ;;
    esac
  fi

  local -i format_len=0 mfl=0 i=0 j=0

  yaml::type mod_fmt_type "${format}"
  local -a fields=() value_fields=()
  local __prev_len0="${__ff_len0}"
  local fmt_is_str=$((mod_fmt_type == YAML_STRING))

  case "${mod_fmt_type}" in
    $YAML_STRING) --mirkop-format-fields format fields format_len ;;
    $YAML_LIST) local -n __nfmfm="${format}"; fields=("${__nfmfm[@]}") ;;
    *) return 1 ;;
  esac

  local fcount="${#fields[@]}"
  local max_render=$((fmt_is_str ? fcount : ${cm[max]:-${fcount}}))

  if ((fcount == 0)); then
    ((__ff_len0 += format_len, fmt_is_str)) && printf -v "${1}" '%s' "${format}"
    return 0
  fi

  local field kname vname is_opt_val has_opt_data opt_data
  for ((i = 0; i < fcount && max_render > 0; i++)); do
    field="${fields[i]#\?}"
    if ((is_opt_val = ${#fields[i]} != ${#field}, is_opt_val)); then
      opt_data="${field#*:}"
      ((has_opt_data = ${#opt_data} != ${#field}, has_opt_data)) \
        && field="${field%":${opt_data}"}" || opt_data=''
    fi
    vname="${field#*.}"
    kname="${field%."${vname}"}"

    case "${kname}" in
      'battery')
        if [[ "${vname}" == 'icon' ]]; then
          if [[ "${POWER_SUPPLY_STATUS}" == "Charging" ]]; then
            fields[i]=''
          else
            case "$((POWER_SUPPLY_CAPACITY - (POWER_SUPPLY_CAPACITY % 10)))" in
              100) fields[i]='󰁹' ;;
              90)  fields[i]='󰂂' ;;
              80)  fields[i]='󰂁' ;;
              70)  fields[i]='󰂀' ;;
              60)  fields[i]='󰁿' ;;
              50)  fields[i]='󰁾' ;;
              40)  fields[i]='󰁽' ;;
              30)  fields[i]='󰁼' ;;
              20)  fields[i]='󰁻' ;;
              10)  fields[i]='󰁺' ;;
              0)   fields[i]='󰂎' ;;
            esac
          fi
        elif [[ -v "POWER_SUPPLY_${vname^^}" ]]; then
          vname="POWER_SUPPLY_${vname^^}"
          fields[i]="${!vname}"
        else
          fields[i]=''
        fi
        ((__ff_len0 += ${#fields[i]}))
        ;;
      'env')
        fields[i]="${__mf_out["${vname}"]}"
        ((__ff_len0 += ${#fields[i]}))
        ;;
      'git')
        fields[i]=''
        ((${#git_info[@]} == 0)) && continue

        case "${vname}" in
          branch) fields[i]="${git_info[branch]}" ;;
          ahead | behind | untracked | untracked_dirs | staged | conflicted)
            gir="${git_info[${vname}]}"
            if ((gir > 0)); then
              ((is_opt_val)) && fields[i]="${opt_data}${gir}" \
                || fields[i]="${gir}"
            elif ((!is_opt_val)); then
              fields[i]="${gir}"
            fi
            ((gir > 0 || !is_opt_val)) && fields[i]="${gir}"
            ;;
          modified | inserted | deleted | changed)
            if ((git_info[modified] > 0)); then
              ((is_opt_val)) && fields[i]="${opt_data}${git_info[${vname}]}" \
                || fields[i]="${git_info[${vname}]}"
            elif ((!is_opt_val)); then
              fields[i]="${git_info[${vname}]}"
            fi
            ;;
        esac
        ((__ff_len0 += ${#fields[i]}))
        ;;
      'jobs')
        read -r num_jobs < <(jobs -p | wc -l)
        fields[i]=''
        ((is_opt_val && num_jobs == 0)) || fields[i]="${opt_data}${num_jobs}"
        ((__ff_len0 += ${#fields[i]}))
        ;;
      'status_code')
        fields[i]=''
        if ((MIRKOP_LAST_STATUS != 0)); then
          ((is_opt_val)) && fields[i]="${opt_data}${MIRKOP_LAST_STATUS}" \
            || fields[i]="${MIRKOP_LAST_STATUS}"
        elif ((!is_opt_val)); then
          fields[i]="${MIRKOP_LAST_STATUS}"
        fi
        ((__ff_len0 += ${#fields[i]}))
        ;;
      'signal_name')
        if ((MIRKOP_LAST_STATUS > 128)); then
          ((is_opt_val)) && fields[i]="${opt_data}"
          case "$((MIRKOP_LAST_STATUS - 128))" in
            1)  fields[i]+='SIGHUP'  ;;
            2)  fields[i]+='SIGINT'  ;;
            3)  fields[i]+='SIGQUIT' ;;
            4)  fields[i]+='SIGILL'  ;;
            6)  fields[i]+='SIGABRT' ;;
            8)  fields[i]+='SIGFPE'  ;;
            9)  fields[i]+='SIGKILL' ;;
            11) fields[i]+='SIGSEGV' ;;
            13) fields[i]+='SIGPIPE' ;;
            14) fields[i]+='SIGALRM' ;;
            15) fields[i]+='SIGTERM' ;;
            *)  fields[i]+="SIG$((MIRKOP_LAST_STATUS - 128))" ;;
          esac
        else
          fields[i]=''
        fi
        ((__ff_len0 += ${#fields[i]}))
        ;;
      'duration')
        [[ -n "${MIRKOP_CMD_TIME}" ]] && \
          --mirkop-timeit-string MIRKOP_CMD_DURATION "${MIRKOP_CMD_TIME}" "${MIRKOP_PS1_TIME}"
        fields[i]="${MIRKOP_CMD_DURATION}"
        ((__ff_len0 += ${#fields[i]}))
        ;;
      'pwd')
        case "${vname}" in
        'tilde') fields[i]="${PWD/#"${HOME}"/\~}" ;;
        'trunc') --mirkop-generate-pwd-short; fields[i]="${MIRKOP_LAST_PWDS}" ;;
        *) fields[i]="${PWD}" ;;
        esac
        ((__ff_len0 += ${#fields[i]}))
        ;;
      *)
        __recursive_result="${fields[i]}"
        fields[i]=''
        --mirkop-parse-format '__recursive_result' || continue
        fields[i]="${__recursive_result}"
        ;;
    esac
    ((max_render--))
  done

  if ((max_render == 0)); then
    for ((;i < fcount; i++)); do
      fields[i]=''
    done
  fi

  ((__ff_len0 == __prev_len0 && fcount > 0)) && return 1
  ((__ff_len0 += format_len))

  local __out_str=''
  case "${mod_fmt_type}" in
    $YAML_LIST)
      local __lf_itm=()
      local -i __lf_itml=0
      for ((i = 0; i < fcount; i++)); do
        [[ -n "${fields[i]}" ]] && __lf_itm[__lf_itml++]="${fields[i]}"
      done

      ((__lf_itml == 0)) && return 1

      if [[ -v 'cm[separator]' ]]; then
        local __join_by="${cm[separator]}"
        __out_str="${__lf_itm[0]}"
        for mn in "${__lf_itm[@]:1}"; do
          __out_str+="${__join_by}${mn}"
        done
        ((__ff_len0 += __lf_itml > 1 ? (__lf_itml - 1) * ${#__join_by} : 0))
      else
        ((__ff_len0 += __lf_itml > 1 ? __lf_itml - 1 : 0))
        __out_str="${__lf_itm[*]}"
      fi

      if [[ "${cm[padend]:-null}" != 'null' ]]; then
        __out_str+="${cm[padend]}"
        ((__ff_len0 += "${#cm[padend]}"))
      fi
      if [[ "${cm[padstart]:-null}" != 'null' ]]; then
        __out_str="${cm[padstart]}${__out_str}"
        ((__ff_len0 += "${#cm[padstart]}"))
      fi
      ;;
    $YAML_STRING)
      printf -v __out_str -- "${format}" "${fields[@]}"
      ;;
  esac

  if [[ -n "${style}" ]]; then
    if [[ "${style}" =~ \$([01]) ]]; then
      local color
      --mirkop-chromahash-generate color "${PWD}"
      style="${style//\$0/"${color[0]}"}"
      style="${style//\$1/"${color[1]}"}"
    fi
    [[ "${__out_var0}" == 'PS1' ]] && __out_str="\\[${style}\\]${__out_str}"$'\[\x1b[0m\]' || __out_str="${style}${__out_str}"$'\x1b[0m'
  fi

  printf -v "${1}" '%s' "${__out_str}"
  return 0
}

function --mirkop-update-prompt {
  MIRKOP_LAST_STATUS=${?}
  MIRKOP_PS1_TIME="${EPOCHREALTIME}"

  local __ps_c='' __ps_l=0
  local -i __col
  # --mirkop-cursor-position _ __col
  # ((__col > 1)) && printf '\x1b[38;5;242m⏎\x1b[0m\n'

  --mirkop-fill-prompt-format PS1 _ "${MIRKOP_PS1}" MIRKOP_PS1_MODS
  if ((MIRKOP_HAS_PSR)); then
    --mirkop-fill-prompt-format __ps_c __ps_l "${MIRKOP_PSR}" MIRKOP_PSR_MODS
    printf '\x1b[%dC%s\x1b[0G' "$((COLUMNS - (__ps_l + MIRKOP_PSR_FLEN)))" "${__ps_c}"
  fi

  ((MIRKOP_HAS_PS2)) && --mirkop-fill-prompt-format PS2 _ "${MIRKOP_PS2}" MIRKOP_PS2_MODS
  --mirkop-set-title "${MIRKOP_LAST_PWDS}"
}

function --mirkop-transient-prompt {
  ((MIRKOP_ALLOW_PST)) || return
  MIRKOP_ALLOW_PST=0
  local __ps_c=''
  local -i __col __ps_l

  if ((MIRKOP_HAS_PST)); then
    --mirkop-fill-prompt-format __ps_c __ps_l "${MIRKOP_PST}" MIRKOP_PST_MODS
    printf "${MIRKOP_PST_FMT}" "${__ps_c}" "${MIRKOP_READLINE_LINE}"
  fi

  if ((MIRKOP_HAS_PSH)); then
    __col=$((MIRKOP_HAS_PST ? MIRKOP_PST_FLEN + __ps_l + ${#MIRKOP_READLINE_LINE} : 0))
    --mirkop-fill-prompt-format __ps_c __ps_l "${MIRKOP_PSH}" MIRKOP_PSH_MODS
    ((__col < COLUMNS - __ps_l)) && printf "${MIRKOP_PSH_FMT}" "$((COLUMNS - __col - (__ps_l + MIRKOP_PSH_FLEN)))" "${__ps_c}"
  fi

  local __mc_t="${MIRKOP_READLINE_LINE#"${MIRKOP_READLINE_LINE%%[![:space:]]*}"}"
  if [[ -n "${__mc_t}" ]]; then
    ((MIRKOP_CMD_ISSPACE && HISTCMD > 1)) && history -d -2
    MIRKOP_CMD_ISSPACE=$((${#MIRKOP_READLINE_LINE} != ${#__mc_t}))

    if [[ "${__mc_t}" != '#'* ]]; then
      --mirkop-set-title "${__mc_t:0:32}"
      MIRKOP_CMD_TIME="${EPOCHREALTIME}"
    fi
  fi
}

function --mirkop-load-config {
  command -v yaml::load &> /dev/null || return
  [[ -f "${1:?missing config path}" ]] || return
  local k

  yaml::load __ynroot "${1}"
  for k in 'prompt' 'styles' 'modules'; do
    yaml::ensure map ".${k}" __ynroot
    local -n "${k}"="${__ynroot["${k}"]}"
  done

  for k in "${!styles[@]}"; do
    --mirkop-style-from-map "${styles["${k}"]}" "MIRKOP_STYLES[${k}]"
  done

  for k in "${!modules[@]}"; do
    if yaml::is map "${modules["${k}"]}"; then
      MIRKOP_MODULES["!${k}"]="${modules["${k}"]}"
    fi
  done

  if yaml::is map "${prompt[chromahash]}"; then
    local -n ch="${prompt[chromahash]}"
    [[ "${ch[mask]}" =~ ^0x[A-Fa-f0-9]+$ || "${cm[mask]}" =~ ^[0-9]+$ ]] && MIRKOP_CHROMAHASH_MASK="${ch[mask]}"
  fi

  local char
  if yaml::is map "${prompt[indicator]}"; then
    local -n pm="${prompt[indicator]}"
    local root_char="${pm[root]}"
    local def_char="${pm[default]}"
  fi
  ((UID == 0)) && char="${root_char:-#}" || char="${def_char:-$}"
  local char_len=$((${#char} + 1))

  [[ "${prompt[left]:-null}" == 'null' ]] && exit 33

  MIRKOP_PS1="${prompt[left]}"
  --mirkop-format-fields-ps MIRKOP_PS1 MIRKOP_PS1_MODS
  MIRKOP_PS1+="${char} "

  if [[ "${prompt[right]:-null}" != 'null' ]]; then
    MIRKOP_PSR="${prompt[right]}"
    --mirkop-format-fields MIRKOP_PSR MIRKOP_PSR_MODS MIRKOP_PSR_FLEN
    MIRKOP_HAS_PSR=$(((MIRKOP_PSR_FLEN + ${#MIRKOP_PSR_MODS[@]}) > 0))
  fi

  if [[ "${prompt[continuation]:-null}" != 'null' ]]; then
    MIRKOP_PS2="${prompt[continuation]}"
    --mirkop-format-fields-ps MIRKOP_PS2 MIRKOP_PS2_MODS
    MIRKOP_PS2+="${char} "
    ((MIRKOP_PS2_FLEN += char_len))
    MIRKOP_HAS_PS2=$(((MIRKOP_PS2_FLEN + ${#MIRKOP_PS2_MODS[@]}) > 0))
  fi

  if yaml::is map "${prompt[transient]}"; then
    local -n transient_p="${prompt[transient]}"

    if [[ "${transient_p[left]:-null}" != 'null' ]]; then
      MIRKOP_PST="${transient_p[left]}"
      --mirkop-format-fields MIRKOP_PST MIRKOP_PST_MODS MIRKOP_PST_FLEN
      MIRKOP_HAS_PST=$(((MIRKOP_PST_FLEN + ${#MIRKOP_PST_MODS[@]}) > 0))
    fi

    if [[ "${transient_p[right]:-null}" != 'null' ]]; then
      MIRKOP_PSH="${transient_p[right]}"
      --mirkop-format-fields MIRKOP_PSH MIRKOP_PSH_MODS MIRKOP_PSH_FLEN
      MIRKOP_HAS_PSH=$(((MIRKOP_PSH_FLEN + ${#MIRKOP_PSH_MODS[@]}) > 0))
    fi

    if ((MIRKOP_HAS_PST)); then
      if [[ "${transient_p[command_style]:-null}" != 'null' ]]; then
        MIRKOP_PST_FMT="${char} ${MIRKOP_STYLES["${transient_p[command_style]}"]}"$'%s\x1b[0m'
      else
        MIRKOP_PST_FMT="${char} %s"
      fi
      ((MIRKOP_PST_FLEN += char_len))
      ((!MIRKOP_HAS_PSH)) && MIRKOP_PST_FMT+=$'\n'
    elif ((MIRKOP_HAS_PSH)); then
      MIRKOP_PSH_FMT='\x1b[A\x1b[%dC%s\n'
    fi
  fi

  readonly \
    MIRKOP_PS1 MIRKOP_PS1_MODS \
    MIRKOP_PS2 MIRKOP_PS2_MODS \
    MIRKOP_PSR MIRKOP_PSR_FLEN MIRKOP_PSR_MODS \
    MIRKOP_PST MIRKOP_PST_FLEN MIRKOP_PST_MODS \
    MIRKOP_PSH MIRKOP_PSH_FLEN MIRKOP_PSH_MODS \
    MIRKOP_HAS_PS2 MIRKOP_HAS_PSR \
    MIRKOP_HAS_PST MIRKOP_HAS_PSH \
    MIRKOP_PST_FMT MIRKOP_PSH_FMT
}

function --mirkop-on-return {
  MIRKOP_READLINE_LINE="${READLINE_LINE}"
  MIRKOP_ALLOW_PST=1
  MIRKOP_CMD_TIME=''
  return 0
}

function --mirkop-on-command {
  local __mc_t="${MIRKOP_READLINE_LINE#"${MIRKOP_READLINE_LINE%%[![:space:]]*}"}"
  printf '\x1b]0;%s\x07' "${__mc_t:0:32}"
  MIRKOP_CMD_TIME="${EPOCHREALTIME}"
}

function mirkop-init {
  --mirkop-load-config "${1:-${HOME}/.config/mirkop.yaml}"
  --mirkop-update-prompt

  [[ -n "${SSH_TTY@A}" ]] && MIRKOP_LOCALITY='remote'
  readonly MIRKOP_LOCALITY
  PROMPT_COMMAND=('--mirkop-update-prompt')
  PS0='${ --mirkop-on-command;}'

  trap -- '--mirkop-transient-prompt' DEBUG
  bind -x '"\e[998~": "--mirkop-on-return"'
  bind '"\e[999~": accept-line'
  bind '"\C-m": "\e[998~\e[999~"'
  trap '((MIRKOP_CMD_ISSPACE && HISTCMD > 1)) && history -d -1' EXIT
}

function --mirkop-full-prompt {
  if ((MIRKOP_HAS_PST)); then
    --mirkop-fill-prompt-format __ps_c __ps_l "${MIRKOP_PST}" MIRKOP_PST_MODS
    printf "${MIRKOP_PST_FMT}" "${__ps_c}"
  fi

  if ((MIRKOP_HAS_PSH)); then
    __col=$((MIRKOP_HAS_PST ? MIRKOP_PST_FLEN + __ps_l + 1 : 0))
    --mirkop-fill-prompt-format __ps_c __ps_l "${MIRKOP_PSH}" MIRKOP_PSH_MODS
    printf "${MIRKOP_PSH_FMT}" "$((COLUMNS - __col - (__ps_l + MIRKOP_PSH_FLEN)))" "${__ps_c}"
  fi

  --mirkop-update-prompt
}

function mirkop-timeit {
  local -i col
  local -i i max=1

  if [[ "${1}" == +([0-9]) ]]; then
    max=${1}
    shift
  elif [[ "${1}" == '--' ]]; then
    shift
  fi

  if ((max > 1)); then
    local start="${EPOCHREALTIME}"
    for ((i=0; i < max; i++)); do
      "${@}" &> /dev/null
    done
    local end="${EPOCHREALTIME}"
  else
    local start="${EPOCHREALTIME}"
    "${@}"
    local end="${EPOCHREALTIME}"
  fi

  local start_s=${start%.*}
  local start_us=${start#*.}
  start_us=${start_us#"${start_us%%[!0]*}"}

  local end_s=${end%.*}
  local end_us=${end#*.}
  end_us=${end_us#"${end_us%%[!0]*}"}

  local diff_s=$((end_s - start_s))
  local diff_us=$((diff_s > 0 ? (1000000 + end_us) - start_us : end_us - start_us))
  ((diff_s > 0 && (diff_us >= 1000000 ? diff_us %= 1000000 : diff_s--)))

  local h=$((diff_s / 3600))
  local m=$(((diff_s % 3600) / 60))
  local s=$((diff_s % 60))
  local ms=$((diff_us / 1000))
  local us=$((diff_us % 1000))

  local times=()
  ((h > 0)) && times+=("${h}h")
  ((m > 0)) && times+=("${m}m")
  ((s > 0)) && times+=("${s}s")
  ((ms > 0 && h == 0)) && times+=("${ms}ms")
  ((us > 0 && h == 0 && ${#times[@]} < 3)) && times+=("${us}us")

  if ((max == 1)); then
    --mirkop-cursor-position _ col
    ((col > 1)) && printf '\x1b[38;5;242m⏎\x1b[0m\n'
    local IFS=''
    printf '\x1b[38;5;249mtook %s\x1b[0m\n' "${times[*]}"
    return
  fi

  local avg_us=$(((diff_s * 1000000 + diff_us) / max))

  local h=$((avg_us / 3600000000))
  local m=$(((avg_us % 3600000000) / 60000000))
  local s=$(((avg_us % 60000000) / 1000000))
  local ms=$(((avg_us % 1000000) / 1000))
  local us=$((avg_us % 1000))

  local time_avrg=()
  ((h > 0)) && time_avrg+=("${h}h")
  ((m > 0)) && time_avrg+=("${m}m")
  ((s > 0)) && time_avrg+=("${s}s")
  ((ms > 0 && h == 0)) && time_avrg+=("${ms}ms")
  ((us > 0 && h == 0 && ${#time_avrg[@]} < 3)) && time_avrg+=("${us}us")

  local IFS=''
  printf '\x1b[38;5;249mtook    %s\naverage %s\x1b[0m\n' "${times[*]}" "${time_avrg[*]}"
}

function mirkop-chromahash (
  [[ "${1}" =~ ^0x[A-Fa-f0-9]+$ || "${1}" =~ ^[0-9]+$ ]] && MIRKOP_CHROMAHASH_MASK="${1}"
  local j=0 d='' path color
  local dummy line fullpath

  local -a paths=() lines=() entries=()
  while IFS=$'\t' read -r path line; do
    paths+=("${path}")
    lines+=("${line}")
  done < <(
    {
      find ~ -maxdepth 1 -mindepth 1 -type d -not -name '.*' -printf '  %p\t%M\t%u\n'
      find ~ -maxdepth 1 -mindepth 1 -type f -not -name '.*' -printf '  %p\t%M\t%u\n'
    } | LC_ALL=C sort -k1 | head -n 25
  )
  local total_entries="${#lines[@]}"
  mapfile -t dummy < <(tr -dc 'a-zA-Z_.-' < /dev/urandom | head -c 9216 | sed 's/\(.\{1,16\}\)/\1\n/g;s/\n$//')

  while true; do
    j=-1
    while ((++j < total_entries)); do
      --mirkop-chromahash-generate color "${paths[j]}"
      printf -v 'entries[j]' '\x1b[38;2;%sm%s %s' "${color[0]}" "${lines[j]}" "${paths[j]}"
    done

    j=0
    for d in "${dummy[@]}"; do
      # ((cidx = ((i++ % 12) + 1 > 6) ^ (j % 12 > 5) ? 1 : 3))
      ((cidx = ((i++ % 24) + 1 > 12) ^ (j > 11) ? 0 : 1))
      --mirkop-chromahash-generate color "${d}"
      printf '\x1b[48;2;%sm  \x1b[0m' "${color[cidx]}"
      ((i % 24 == 0)) && printf ' %s\x1b[0m\n' "${entries[j++]}"
    done

    [[ "${1}" != 'loop' ]] && break
    printf '\x1b[48;2;255;255;255m\x1b[38;2;18;18;28mmask: 0x%-40x\x1b[0m %s\n' \
      "${MIRKOP_CHROMAHASH_MASK}" "${entries[j]}"
    MIRKOP_CHROMAHASH_MASK="${SRANDOM}${SRANDOM}${SRANDOM}${SRANDOM}${MIRKOP_CHROMAHASH_MASK}000000000000"
    MIRKOP_CHROMAHASH_MASK="${MIRKOP_CHROMAHASH_MASK:0:16}"
  done
)

function mirkop-ls (
  local -i cidx=0 long=0 icons=1 inline=1 basename=1 hide_dot=1
  local t='' targets=()

  if [[ "${1}" == '-'* ]]; then
    local i=0 l="${#1}" c=''
    while ((++i < l)); do
      c="${1:i:1}"
      case "${c}" in
        f) basename=0 ;;
        i) icons=0 ;;
        a) hide_dot=0 ;;
        l) long=1 ;;
        d) cidx=1 ;;
        1) inline=0 ;;
        *)
          printf 'Unknown flag "%s"\n' "${c}" >&2
          exit 1
          ;;
      esac
    done
    shift
  fi
  ((${#} > 0)) && targets=("${@}") || targets=('.')

  for i in "${!targets[@]}"; do
    read -r t < <(realpath -eL "${targets[i]}") || t=''
    if [[ ! -d "${t}" ]]; then
      printf 'Not a directory: %s\n' "${targets[i]}" >&2
      return 1
    fi
    targets[i]="${t}"
  done

  local total_dirs="${#targets[@]}"
  local find_args=(-maxdepth 1 -mindepth 1)
  ((hide_dot)) && find_args+=(-not -name '.*')

  if ((inline && !long)); then
    read -r _ cols < <(stty size)
    function print {
      shift 1
      local items=("${@}")
      local count="${#items[@]}"
      local maxl=0
      local e
      for ((e = 1; e < count; e+=2)); do
        ((${#items[e]} > maxl && (maxl = ${#items[e]})))
      done
      local idl=$((maxl + 3))
      local iil=$((cols / idl))
      local lines=()
      local lct=$(((count / iil) - 1))
      local lri=$((count % iil))
      local ln=0
      local i=0
      local c=1
      while ((i < count)); do
        printf -v item "%s%-${idl}s" "${items[i]}" "${items[i+1]}"
        lines[ln]="${lines[ln]}${item}"
        ((i+=2))
        if ((ln == lct)); then
          if ((lri > 0)); then
            ((ln++))
            printf -v item "%s%-${idl}s" "${items[i]}" "${items[i+1]}"
            lines[ln]="${lines[ln]}${item}"
            ((lri--))
            ((i+=2))
          fi
          ((c++))
          ln=0
          ((c > iil)) && break
        else
          ((ln++))
        fi
      done
      ((count % 2 != 0)) && lines+=('')
      printf '%s\n' "${lines[@]}"
    }
  else
    function print { printf "${@}"; }
  fi

  icond='  '
  iconf='  '
  ((!icons)) && icond='' iconf=''
  for ((i = 0; i < total_dirs; i++)); do
    t="${targets[i]}"
    local -a entries=()
    local line path color

    while IFS=$'\t' read -r path line; do
      --mirkop-chromahash-generate color "${path}"
      ((basename)) && path="${path##*/}"
      entries+=($'\x1b'"[38;2;${color[cidx]}m" "${icond}${path}")
      ((long)) && printf -v 'entries[-1]' '%s %s\x1b[0m' "${line}" "${icond}${path}"
    done < <(find "${t}" "${find_args[@]}" -type d -printf '%p\t%M %u\t%TY %Tb %Td %TH:%TM\n' 2>/dev/null | LC_ALL=C sort -k1)

    while IFS=$'\t' read -r path line; do
      --mirkop-chromahash-generate color "${path}"
      ((basename)) && path="${path##*/}"
      entries+=($'\x1b'"[38;2;${color[cidx]}m" "${iconf}${path}")
      ((long)) && printf -v 'entries[-1]' '%s %s\x1b[0m' "${line}" "${iconf}${path}"
    done < <(find "${t}" "${find_args[@]}" -type f -printf '%p\t%M %u\t%TY %Tb %Td %TH:%TM\n' 2>/dev/null | LC_ALL=C sort -k1)

    if ((total_dirs > 1)); then
      --mirkop-chromahash-generate color "${targets[i]}"
      printf '\x1b[38;2;%sm%s\x1b[0m:\n' "${color}" "${targets[i]}"
      ((i < total_dirs - 1)) && entries+=('')
    fi
    print '%s%s\x1b[0m\n' "${entries[@]}"
  done
)
