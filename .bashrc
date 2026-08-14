# ~/.bashrc
[[ "${-}" != *i* ]] && return

function source {
  builtin source "${@}" || exit "${?}"
}

HISTCONTROL='erasedups' #:ignoreboth'
HISTIGNORE='&:ls:cd:pwd:rm*:sudo rm*:git clone*'
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s gnu_errfmt histappend histverify histreedit \
  failglob autocd cdspell dirspell checkwinsize \
  dotglob extglob globstar patsub_replacement \

source ~/.config/bash/functions.sh
source ~/.config/bash/bettercd.sh
source ~/.config/bash/carapace.sh
source ~/.config/bash/bargcomp.sh
[[ -r ~/.cargo/env ]] && source ~/.cargo/env
[[ -r ~/.config/dotf/set-env-lines.sh ]] && source ~/.config/dotf/set-env-lines.sh

alias lg='lazygit'
alias ls='ls --color=yes'
alias wdc='windscribe-cli'
alias git='git --no-pager'
alias nano='vim'

bind -x '"\C-l": clear'
bind -x '"\C-o": --nvim-open-files-fuzzy'

printf -v PAD28 '%28s'
PS4='# \[\e[0m\e[38;2;168;230;179m\][${#FUNCNAME[@]}][${FUNCNAME:-?}${PAD28:${#FUNCNAME}}]\[\e[0m\] '
: "$((UID == 0 ? 342234246 : 342211273))"
: "${_//???/\\&}"
PS1='\[\e[38;5;50m\]\u\[\e[0m\] in \[\e[38;5;141m\]\h\[\e[0m\] \[\e[38;5;243m\]${ pwd-truncated;}\[\e[0m\]'"${_@P} "

if [[ -r ~/.local/mirkop.sh && ~/.config/mirkop.yaml -nt ~/.cache/mirkop-prompt.sh ]]; then
  printf 'Regenerating prompt...\n'
  bash ~/.local/mirkop.sh ~/.config/mirkop.yaml ~/.cache/mirkop-prompt.sh
fi

if [[ -r ~/.cache/mirkop-prompt.sh ]]; then
  source ~/.cache/mirkop-prompt.sh
  PROMPT_COMMAND=('mirkop-init')
fi

! shopt -q login_shell && return
