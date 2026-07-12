# ~/.config/zsh/.zshenv

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

export EDITOR="nvim"
export VISUAL="nvim"

if command -v bat >/dev/null 2>&1; then
  export MANPAGER="bat -l man -p"
elif command -v batcat >/dev/null 2>&1; then
  export MANPAGER="batcat -l man -p"
fi

export PATH="$HOME/.local/bin:$PATH"

# Go toolchain from go.dev lands in /usr/local/go; distro packages use /usr/bin.
# $HOME/go/bin is GOPATH/bin, where `go install` puts binaries.
[ -d /usr/local/go/bin ] && export PATH="/usr/local/go/bin:$PATH"
[ -d "$HOME/go/bin" ] && export PATH="$HOME/go/bin:$PATH"

export GPG_TTY="$(tty 2>/dev/null || true)"
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"


# . "$HOME/.cargo/env"
