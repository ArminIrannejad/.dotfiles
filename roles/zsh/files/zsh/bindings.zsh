# Run directly, typing it via bindkey -s gets highlighted char by char
_sessionizer() { tmux-sessionizer </dev/tty; zle reset-prompt }
_sessionizer_w() { tmux-sessionizer -w </dev/tty; zle reset-prompt }
zle -N _sessionizer
zle -N _sessionizer_w

zvm_config() {
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK

ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none
}

zvm_after_init() {
  bindkey '^[[1;5C' forward-word
  bindkey '^[[1;5D' backward-word
  bindkey '^\' autosuggest-toggle
  bindkey '^y' autosuggest-accept

  bindkey -M viins '^[[A' history-substring-search-up
  bindkey -M viins '^[[B' history-substring-search-down
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey "$terminfo[kcuu1]" history-substring-search-up
  bindkey "$terminfo[kcud1]" history-substring-search-down

  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
  bindkey -M viins '^F' _sessionizer
  bindkey -M vicmd '^F' _sessionizer
  bindkey -M viins '^G' _sessionizer_w
  bindkey -M vicmd '^G' _sessionizer_w
}

