#!/bin/zsh

CONFIG="${HOME}/.config/dotfiles/env"
alias envini="git config -f $CONFIG"

variables=$(envini --list | grep '^variables\.' | sed 's/^variables\.//g')
for var in $variables; do
   export $var
done
