export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
