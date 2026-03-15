# shellcheck shell=bash
# Two-line colored prompt: user@host workdir on line 1, $ on line 2
PS1='\[\033[1;32m\]\u@\h\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\n\$ '
export PS1

alias v=nvim vi=nvim vim=nvim
alias install='~/work/scripts/install.sh'
alias se='source ~/.bashrc'
