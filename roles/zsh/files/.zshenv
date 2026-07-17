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

# Prefer an explicitly configured JDK, otherwise use the standard path from
# the Fedora Java role or Debian/Ubuntu's default Java symlink.
if [[ -z "$JAVA_HOME" ]]; then
  for java_home in /usr/lib/jvm/java-25-openjdk /usr/lib/jvm/default-java; do
    if [[ -d "$java_home" ]]; then
      export JAVA_HOME="$java_home"
      break
    fi
  done
  unset java_home
fi

[[ -d "$JAVA_HOME/bin" ]] && export PATH="$JAVA_HOME/bin:$PATH"

# Go toolchain from go.dev lands in /usr/local/go; distro packages use /usr/bin.
# $HOME/go/bin is GOPATH/bin, where `go install` puts binaries.
[ -d /usr/local/go/bin ] && export PATH="/usr/local/go/bin:$PATH"
[ -d "$HOME/go/bin" ] && export PATH="$HOME/go/bin:$PATH"

export GPG_TTY="$(tty 2>/dev/null || true)"
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"


# . "$HOME/.cargo/env"
