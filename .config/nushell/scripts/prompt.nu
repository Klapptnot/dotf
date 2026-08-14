# 🔗 https://github.com/klapptnot/dotf

$env.mirkov = {
  ldir: "",
  sdir: "",
  cdir: "",
  user: $env.USER
  host: (hostname)
  from:  (if ($env.SSH_TTY? | default nothing) == nothing {' in '} else {' at '})

  cuser: (ansi {fg: '#cdb4f5'}),
  cfrom: (ansi {fg: '#8f8fb3'}),
  chost: (ansi {fg: '#f4b8d4'}),
  cerr:  (ansi {fg: '#f5a3a3', attr: bold})

  git_color: {
    i: (ansi {fg: '#a8e6b3'})
    d: (ansi {fg: '#f5a3a3'})
    a: (ansi {fg: '#c2a8e6'})
    s: (ansi {fg: '#a3a3c2'})
  }

  creset:       (ansi reset),
  ctime:        (ansi {fg: '#a8d8f0'}),
  ctime_sep:    (ansi grey85),
  ctime_period: (ansi white_underline),
  cduration:    (ansi plum1),
}
$env.mirkov.char = $'(ansi {fg: '#8f8fb3'})(if (is-admin) {'󱐋'} else {'❯'})($env.mirkov.creset) '
$env.mirkov.date_fmt = $'(ansi {fg: '#7d7d94'})%I:%M:%S %p($env.mirkov.creset)'

def path-shorten []: string -> string {
  let path_parts = ($in | path split)

  $path_parts | drop 1 | each { |part|
    match $part {
      "" => $part,
      $s if ($s | str starts-with ".") => ($s | str substring 0..1),
      $s => ($s | str substring 0..0)
    }
  } | append ($path_parts | last) | path join
}

def get-git-info []: nothing -> record<modified: int, inserted: int, deleted: int, untracked: int, folders: int, branch: string> {
  mut stats = (
    git diff --shortstat
      | parse --regex '\s*(?<modified>[0-9]+)[^0-9]*(?<inserted>[0-9]+)[^0-9]*(?<deleted>[0-9]+)'
      | into record | update cells { into int }
  )

  let untracked = (git ls-files --other --exclude-standard | lines)
  let u_folders = ($untracked | path dirname | uniq | length)
  $stats.modified = $stats.modified? | default 0
  $stats.inserted = $stats.inserted? | default 0
  $stats.deleted = $stats.deleted? | default 0
  $stats.untracked = ($untracked | length)
  $stats.folders = $u_folders
  $stats.branch = (git branch --show-current)

  $stats
}

def __left_prompt_command [--transient]: nothing -> string {
  let dir = match (do --ignore-errors { $env.PWD | path relative-to $nu.home-dir }) {
    null => $env.PWD
    '' => '~'
    $relative_pwd => ([~, $relative_pwd] | path join)
  }

  if $env.mirkov.ldir != $dir {
    $env.mirkov.ldir = $dir
    $env.mirkov.sdir = ($dir | path-shorten)
    $env.mirkov.cdir = ansi --escape { fg: $"#($dir | hash md5 | str substring ..5)" }
  }

  if $transient {
    return $"($env.mirkov.cdir)($env.mirkov.sdir)(ansi reset)"
  }

  [
    $env.mirkov.cuser,
    $env.mirkov.user,
    $env.mirkov.creset,
    $env.mirkov.cfrom,
    $env.mirkov.from,
    $env.mirkov.creset,
    $env.mirkov.chost,
    $env.mirkov.host,
    $env.mirkov.creset,
    ' ',
    $env.mirkov.cdir,
    $env.mirkov.sdir,
    $env.mirkov.creset,
  ] | str join
}

def __right_prompt_command [--transient]: nothing -> string {
  mut parts = []

  if not $transient {
    if ($env.LAST_EXIT_CODE != 0) {
      $parts ++= [$env.mirkov.cerr, ($env.LAST_EXIT_CODE | into string), "? "]
    }

    if (git rev-parse --is-inside-work-tree | complete).exit_code == 0 {
      let color = $env.mirkov.git_color
      let data = (get-git-info)

      if 120 > (term size).columns {
        $parts ++= [$color.s, " ", $color.a, $data.branch, $color.s, $env.mirkov.creset, " "]
      } else {
        $parts ++= [
          $color.s, " ", $color.a, $data.branch, $color.s
          " ", $color.i, "+", $data.inserted, $color.s, "/", $color.d, "-", $data.deleted, $color.a,
          " ", $data.untracked, $color.s, "…", $color.a, $data.folders, $env.mirkov.creset, " "
        ]
      }
    }

    let duration = history | last | get --optional duration
    if $duration != null {
      $duration | into string | str replace --regex --all '([0-9]+)' $"($env.mirkov.cduration)${1}($env.mirkov.creset)"
    }
  }

  $parts ++= [$env.mirkov.ctime, (date now | format date $env.mirkov.date_fmt)]

  $parts | str join
}

$env.PROMPT_COMMAND = {|| __left_prompt_command }
$env.PROMPT_COMMAND_RIGHT = {|| __right_prompt_command }
$env.PROMPT_INDICATOR = {|| $env.mirkov.char }
$env.TRANSIENT_PROMPT_COMMAND = {|| __left_prompt_command --transient }
$env.TRANSIENT_PROMPT_COMMAND_RIGHT = {|| __right_prompt_command --transient }
$env.TRANSIENT_PROMPT_INDICATOR = {|| $env.mirkov.char }
