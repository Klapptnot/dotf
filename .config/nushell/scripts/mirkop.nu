# $format | str replace --all --regex '\{(\{?[^}]*\}?)\}' fill-fields

let mirko = do {
  let mirko_path = ([$env.HOME, ".config", "mirkop.yaml"] | path join)
  mut m = open $mirko_path
  $m.styles = $m.styles | items {|k, v| {$k: (ansi $v)} } | into record
  $m.reset = (ansi reset)
  $m.locality = (if ($env.SSH_TTY? | default nothing) == nothing { 'local' } else { 'remote' })
  $m
}

if not (($mirko.prompt | describe) starts-with 'record') {
  return
}

let mirkop_field_filler = {|m|
  if not (($mirko.modules | get --optional $m | describe) starts-with 'record') {
    return ""
  }

  let module = $mirko.modules | get $m
  let mkind = $module | get --optional kind | default "null"

  let format = if $mkind != "at" and $mkind != "char" {
    if not (($module | get --optional format | describe) == 'string') {
      return ""
    }

    let mf = if $mkind == 'date' {
      let mf = $module | get format
      date now | format date $mf
    } else if $mkind == 'at' {
      $module | get $mirko.locality
    } else { $module | get format }

    $mf | str replace --all --regex '\{(\{?[^}]*\}?)\}' {|k|
      if $k == '&' { return $mirko.reset }
      if $k starts-with & {
        let name = $k | str substring 1..
        return $mirko.styles | get --optional $name | default ""
      }
      if $k starts-with ! {
        let name = $k | str substring 1..
        return $env | get --optional $name | default ""
      }

      let opt = $k starts-with ?
      mut k = if $k =~ ^[/?] { $k | str substring 1.. } else { $k }

      if $k == duration {
        let duration = history | last | get --optional duration
        return (if $duration != null { $duration | into string | str replace --all ' ' ''} else {'--'})
      }

      if $k starts-with 'jobs' {
        $k = $k | str substring 4..
        let fill = if $opt { if $k starts-with : { $k | str substring 1.. } else {' '} } else {''}
        let jobs = jobs list | length
        return (if $jobs == 0 and $opt {''} else { $"($fill)($jobs)" })
      }

      if $k starts-with 'status_code' {
        $k = $k | str substring 11..
        let fill = if $opt { if $k starts-with : { $k | str substring 1.. } else {' '} } else {''}
        return (if $env.LAST_EXIT_CODE == 0 and $opt {''} else { $"($fill)($env.LAST_EXIT_CODE)" })
      }

      if $k starts-with 'signal_name' {
        $k = $k | str substring 11..
        let fill = if $opt { if $k starts-with : { $k | str substring 1.. } else {' '} } else {''}
        return (if $env.LAST_EXIT_CODE <= 128 and $opt {''} else {
          let code = $env.LAST_EXIT_CODE
          let sig = match ($code - 128) {
            1 => 'SIGHUP'
            2 => 'SIGINT'
            3 => 'SIGQUIT'
            4 => 'SIGILL'
            5 => 'SIGTRAP'
            6 => 'SIGABRT'
            7 => 'SIGBUS'
            8 => 'SIGFPE'
            9 => 'SIGKILL'
            10 => 'SIGUSR1'
            11 => 'SIGSEGV'
            12 => 'SIGUSR2'
            13 => 'SIGPIPE'
            14 => 'SIGALRM'
            15 => 'SIGTERM'
            16 => 'SIGSTKFLT'
            17 => 'SIGCHLD'
            18 => 'SIGCONT'
            19 => 'SIGSTOP'
            20 => 'SIGTSTP'
            21 => 'SIGTTIN'
            22 => 'SIGTTOU'
            23 => 'SIGURG'
            24 => 'SIGXCPU'
            25 => 'SIGXFSZ'
            26 => 'SIGVTALRM'
            27 => 'SIGPROF'
            28 => 'SIGWINCH'
            29 => 'SIGIO'
            30 => 'SIGPWR'
            31 => 'SIGSYS'
            _ => $"SIG($code)"
          }
          $"($fill)($sig)"
        })
      }

      $k
    }
  }

  let value = match $mkind {
    "pwd" => {
      $format | str replace --all --regex '\{(\{?[^}]*\}?)\}' {|k|
        match $k {
          "short" => {
            let path_parts = ($in | path split)

            $path_parts | drop 1 | each { |part|
              match $part {
                "" => $part,
                $s if ($s | str starts-with ".") => ($s | str substring 0..1),
                $s => ($s | str substring 0..0)
              }
            } | append ($path_parts | last) | path join
          }
          _ => $k
        }
      }
    }
    _ => $format
  }

  let style_name = $module | get --optional style
  let style = if $style_name != null {
    $mirko.styles | get --optional $style_name
  }

  if $style != null {
    $"($style)($value)(ansi reset)"
  } else {
    $value
  }
}

do $mirkop_field_filler time

# $env.PROMPT_COMMAND = {|| __left_prompt_command }
# $env.PROMPT_COMMAND_RIGHT = {|| __right_prompt_command }
# $env.PROMPT_INDICATOR = {|| '' }
#
# if ($mirko.prompt.transient | describe) starts-with 'record' {
#   $env.TRANSIENT_PROMPT_COMMAND = {|| __left_prompt_command --transient }
#   $env.TRANSIENT_PROMPT_COMMAND_RIGHT = {|| __right_prompt_command --transient }
#   $env.TRANSIENT_PROMPT_INDICATOR = {|| '' }
# }
