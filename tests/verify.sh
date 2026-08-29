#!/bin/bash
# Post-run assertions. Exits non-zero if anything expected is missing.
fail=0
ok()   { printf '  OK    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }

check_cmd() {
  local label="$1" bin="$2"
  if p=$(PATH="$HOME/.cargo/bin:$HOME/.local/bin:$HOME/go/bin:/usr/local/go/bin:$PATH" command -v "$bin" 2>/dev/null); then
    ok "$label -> $p"
  else
    bad "$label ($bin not found)"
  fi
}

echo "== binaries =="
for b in bat btop cmake curl eza fastfetch fd fzf gh git go hyperfine java jq \
         lua nvim node npm python3 rg starship tmux tree unzip wget zoxide zsh uv terraform podman; do
  check_cmd "$b" "$b"
done
check_cmd "rustup" rustup
check_cmd "cargo"  cargo
check_cmd "rustc"  rustc

echo "== rust toolchain =="
export PATH="$HOME/.cargo/bin:$PATH"
if [ -x "$HOME/.cargo/bin/rustup" ]; then
  ok "rustup: $(rustup --version 2>&1 | head -1)"
  ok "rustc:  $(rustc --version 2>&1)"
  ok "which cargo: $(command -v cargo)"
  for c in clippy rust-analyzer rustfmt; do
    if rustup component list --installed 2>/dev/null | grep -q "^$c"; then ok "component $c"; else bad "component $c"; fi
  done
  case "$(command -v cargo)" in
    "$HOME/.cargo/bin/cargo") ok "cargo resolves to rustup, not the distro package" ;;
    *) bad "cargo resolves to $(command -v cargo)" ;;
  esac
else
  bad "rustup not installed"
fi

echo "== distro rust removed =="
if   command -v pacman >/dev/null 2>&1; then pacman -Q rust  >/dev/null 2>&1 && bad "distro rust still installed"  || ok "no distro rust"
elif command -v rpm    >/dev/null 2>&1; then rpm -q rust     >/dev/null 2>&1 && bad "distro rust still installed"  || ok "no distro rust"
elif command -v dpkg   >/dev/null 2>&1; then dpkg -s rustc   >/dev/null 2>&1 && bad "distro rustc still installed" || ok "no distro rustc"
fi

echo "== login shell =="
shell=$(getent passwd "$(id -un)" | cut -d: -f7)
case "$shell" in
  */zsh) ok "login shell is $shell" ;;
  *)     bad "login shell is $shell" ;;
esac
grep -q zsh /etc/shells 2>/dev/null && ok "zsh listed in /etc/shells" || bad "zsh missing from /etc/shells"

echo "== dotfile links =="
for f in .zshrc .zshenv; do
  if [ -L "$HOME/$f" ]; then ok "$f -> $(readlink "$HOME/$f")"; else bad "$f is not a symlink (stale file survived)"; fi
done
[ -d "$HOME/.config/zsh/plugins/fzf-tab" ] && ok "zsh plugins cloned" || bad "zsh plugins missing"

echo "== upstream tarballs beat distro packages =="
# /usr/sbin and /usr/bin are the same directory on merged-usr distros, so
# resolve the link before judging where go came from.
case "$(readlink -f "$(command -v go 2>/dev/null)" 2>/dev/null)" in
  /usr/local/go/bin/go) ok "go from upstream tarball: $(go version)" ;;
  *) bad "go resolves to $(command -v go)" ;;
esac
nvim --version 2>/dev/null | head -1 | grep -q NVIM && ok "nvim: $(nvim --version | head -1)" || bad "nvim not runnable"

echo "== AUR helper =="
if command -v pacman >/dev/null 2>&1; then
  if paru --version >/dev/null 2>&1; then
    ok "paru: $(paru --version 2>&1 | head -1)"
  else
    bad "paru not usable: $(paru --version 2>&1 | head -1)"
  fi
else
  ok "not Arch, AUR helper not applicable"
fi

echo
[ $fail -eq 0 ] && echo "VERIFY: PASS" || echo "VERIFY: FAIL"
exit $fail
