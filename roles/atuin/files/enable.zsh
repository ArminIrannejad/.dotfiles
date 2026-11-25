# Source from an interactive zsh prompt to enable Atuin for this session.
[[ -o interactive ]] || return 0

() {
  if ! command -v atuin >/dev/null 2>&1; then
    print -u2 'Atuin not found on PATH. Run dotfiles -t atuin first.'
    return 1
  fi

  if (( ! ${+widgets[atuin-search-viins]} || ! ${+widgets[atuin-search-vicmd]} )); then
    # Atuin prepends its own strategy. Keep that change local to this function.
    local -a ZSH_AUTOSUGGEST_STRATEGY=("${ZSH_AUTOSUGGEST_STRATEGY[@]}")
    local atuin_init
    atuin_init=$(atuin init zsh --disable-ctrl-r --disable-up-arrow) || return 1
    eval "$atuin_init" || return 1
  fi

  _dotfiles_atuin_bindkeys() {
    bindkey -M emacs '^R' atuin-search
    bindkey -M viins '^R' atuin-search-viins
    bindkey -M vicmd '^R' atuin-search-vicmd
    bindkey -M viins '^X^A' atuin-search-viins
    bindkey -M vicmd '^X^A' atuin-search-vicmd
  }

  # Apply again after zsh-vi-mode sets its own history bindings.
  if (( ${+functions[zvm_init]} && ! ${zvm_after_init_commands[(I)_dotfiles_atuin_bindkeys]} )); then
    zvm_after_init_commands+=(_dotfiles_atuin_bindkeys)
  fi
  _dotfiles_atuin_bindkeys
}
