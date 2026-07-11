export PATH="$HOME/.dotfiles/tmux:$PATH"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias ll='eza -lh --icons --git'
  alias lla='eza -lah --icons --git'
  alias tree='eza --tree --icons'
  compdef eza=ls
else
  alias ll='ls -lh'
  alias lla='ls -lah'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat'
fi

alias precum='pre-commit run -a'
alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias -- -='cd -'
alias vim='nvim'
alias activate="source .venv/bin/activate"
if command -v tmux-sessionizer >/dev/null 2>&1; then
  bindkey -s ^f "tmux-sessionizer\n"
fi
alias time="/usr/bin/time -f $'\n\033[1;34mreal\033[0m %E\n\033[1;32muser\033[0m %U\n\033[1;31msys \033[0m %S'"

