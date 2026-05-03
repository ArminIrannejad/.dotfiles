export PATH="$HOME/.dotfiles/tmux:$PATH"
export PATH="$HOME/.local/src/neovim/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/.config/emacs/bin:$PATH"

alias time="/usr/bin/time -f $'\n\033[1;34mreal\033[0m %E\n\033[1;32muser\033[0m %U\n\033[1;31msys \033[0m %S'"
alias activate="source .venv/bin/activate"
alias vim='nvim'
alias cat='batcat'
alias ls='ls --color=auto'
alias l='ls -F --color=auto'
alias la='ls -a --color=auto'
alias ll='ls -lh --color=auto'
alias lla='ls -lah --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'
alias less='less -R'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'




bindkey -s ^f "tmux-sessionizer\n"
