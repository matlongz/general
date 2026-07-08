# Portable shell aliases — source this from your machine-local rc
# (e.g. `. ~/.config/dotfiles/templates/shell_aliases.sh` in ~/.bash_profile
# or ~/.bashrc). Kept here so aliases sync across machines while machine-
# specific PATH/SDK lines stay in the untracked local rc.

# Dotfiles bare repo (matlongz/general, work-tree = $HOME). Track configs in
# place, no symlinks. Usage: general status | general add <path> | general commit | general push
alias general='git --git-dir=$HOME/.general.git --work-tree=$HOME'

alias ls='ls -F'
