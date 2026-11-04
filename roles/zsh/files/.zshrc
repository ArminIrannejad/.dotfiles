# zmodload zsh/zprof
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

autoload -Uz compinit

zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${zcompdump:h}"

if [[ -z "$_COMPINIT_DONE" ]]; then # to avoid multiple calls, 186ms -> 54ms
  typeset -g _COMPINIT_DONE=1

  if [[ -f "$zcompdump" ]]; then
    compinit -C -d "$zcompdump"
  else
    compinit -d "$zcompdump"
  fi
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

for zsh_config in fzf aliases bindings plugins prompt; do
  [[ -f "$ZDOTDIR/${zsh_config}.zsh" ]] && source "$ZDOTDIR/${zsh_config}.zsh"
done

[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"
export PATH="$HOME/.cargo/bin:$PATH"
