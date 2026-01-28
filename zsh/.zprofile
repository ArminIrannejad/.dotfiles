export PATH="$HOME/.dotfiles/tmux:$PATH"
export PATH="$HOME/.local/src/neovim/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/.config/emacs/bin:$PATH"

btime() {
  /usr/bin/time -p "$@" 2> >(awk '
    BEGIN { r=u=s="" }
    /^real / { r=$2 }
    /^user / { u=$2 }
    /^sys  / { s=$2 }
    END {
      # default zero if missing
      if (r=="") r=0; if (u=="") u=0; if (s=="") s=0

      print "real\t" fmt(r)
      print "user\t" fmt(u)
      print "sys\t"  fmt(s)
    }
    function fmt(x,  h,m,s) {
      h = int(x/3600); m = int((x - h*3600)/60); s = x - h*3600 - m*60
      if (h > 0)  return sprintf("%dm%.3fs", h*60+m, s)
      else        return sprintf("%dm%.3fs", m, s)
    }
  ' >&2)
} # awkward but only way I could get it to work


alias time='btime'
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
