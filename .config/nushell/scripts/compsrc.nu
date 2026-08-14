# get env var :cmpsrc.nu
def --env get-env [name: string] { $env | get $name }
# add or edit env var :cmpsrc.nu
def --env set-env [name: string, value: any] { load-env { $name: $value } }
# remove env var :cmpsrc.nu
def --env unset-env [name: string] { hide-env $name }

let __compsrc_exec: list<string> = (if ('~/.config/.bargcomp.yaml' | path exists) { open ~/.config/.bargcomp.yaml } else { [] })
$env.config.completions.external = {
  enable: true
  max_results: ($env.config | get --optional completions.external.max_results | default 2)
  completer: { |spans: list<string>|
    # if the current command is an alias, get it's expansion
    let expanded_alias = (scope aliases | where name == $spans.0 | get --optional 0.expansion)

    # shadow
    let spans = (
      if $expanded_alias != null  {
        $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
      } else {
        $spans
      }
    )
    let cmd_name: string = $spans.0

    let comps = (
      if ($cmd_name in $__compsrc_exec) {
        (^$cmd_name @nucomp ...($spans))
      } else if ([~/.local/comp/ $cmd_name] | path join | path exists) {
        let comp_f = [~/.local/comp/ $cmd_name] | path join | path expand
        (^$comp_f ...($spans))
      } else {
        # carapace is annoying when it gives no results
        # and you can't append a file path to the command line
        (
          CARAPACE_LENIENT=1 CARAPACE_MATCH=1
          CARAPACE_BRIDGES='clap,cobra,complete,inshellisense'
          carapace $cmd_name nushell ...$spans
        )
      }
    )


    # So, fallback to nushell if its empty
    if $comps != '[]' {
      ($comps | from json)
    }
  }
}
