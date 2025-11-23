export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
HISTFILE=$HOME/.zsh_history

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



ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZVM_CURSOR_STYLE_ENABLED=false

function zvm_after_init() {
  bindkey -M viins -s '^F' "tmux-sessionizer\n"
  bindkey -M vicmd -s '^F' "tmux-sessionizer\n"
}

ZSH_PLUGIN_DIR="$HOME/.zsh/plugins"

if [ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [ -f "$ZSH_PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh" ]; then
  source "$ZSH_PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh"
fi

source /usr/share/doc/fzf/examples/key-bindings.zsh
source /usr/share/doc/fzf/examples/completion.zsh


bindkey -M viins '^[[A' history-substring-search-up
bindkey -M viins '^[[B' history-substring-search-down
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down


if [ -f "$ZSH_PLUGIN_DIR/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]; then
  source "$ZSH_PLUGIN_DIR/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fi

if [ -f "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

[ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"

export CONDA_CHANGEPS1=false

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/armino112/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/armino112/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/home/armino112/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/armino112/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
# Created by `pipx` on 2025-08-25 11:32:50
export PATH="$PATH:/home/armino112/.local/bin"

# opam configuration
[[ ! -r /home/armino112/.opam/opam-init/init.zsh ]] || source /home/armino112/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

[ -f "/home/armino112/.ghcup/env" ] && . "/home/armino112/.ghcup/env" # ghcup-env
export PATH="$HOME/.local/bin:$HOME/.cabal/bin:$PATH"

type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(/usr/local/bin/starship init zsh)"
  }

