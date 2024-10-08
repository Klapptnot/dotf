# |>----|>----|>----|><-><|----<|----<|----<|
# |>    from Klapptnot's Nushell config    <|
# |>   https://github.com/Klapptnot/dotf   <|
# |>----|>----|>----|><-><|----<|----<|----<|

use std

$env.NULL_DEV = (std null-device)
$env.FZF_DEFAULT_COMMAND = 'fd --follow --hidden --exclude .git'
$env.LS_COLORS = (vivid generate 'catppuccin-mocha' | str trim)
$env.UTILS = ([$env.HOME, "repos", "utils"] | path join)

$env.PATH = ([
  $env.PATH,
  ([$env.HOME, ".cargo", "bin"] | path join),
  ([$env.HOME, ".local", "bin"] | path join),
  ([$env.HOME, "bin"] | path join),
  ([$env.HOME, "repos", "utils", "bin"] | path join),
  ([$nu.default-config-dir, "bin"] | path join),
] | uniq)

source ~/.config/nushell/scripts/functions.nu # Helper functions
source ~/.config/nushell/scripts/mirkop.nu    # Prompt functions
source ~/.config/nushell/scripts/goto.nu      # Alias based `cd`
source ~/.config/nushell/scripts/carapace.nu  # Completions helper

alias git = git --no-pager

