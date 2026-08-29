#!/bin/bash
# Run the playbook against throwaway containers for each supported distribution.
#
#   tests/run.sh                    # every distro
#   tests/run.sh arch fedora        # a subset
#   tests/run.sh arch -- -t rust    # extra args go to ansible-playbook
#
# The images start "dirty": distro rust/go/neovim are pre-installed and there
# are stale ~/.zshrc and ~/.zshenv files, so the roles have to displace them.
# Haskell is skipped by default; GHC is a multi-gigabyte download.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
all=(arch omarchy fedora ubuntu)
distros=()
extra=(--skip-tags haskell)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift; extra=("$@"); break ;;
    *) distros+=("$1"); shift ;;
  esac
done
[[ ${#distros[@]} -eq 0 ]] && distros=("${all[@]}")

build() {
  local distro="$1"
  # omarchy layers on top of the arch image
  [[ "$distro" == omarchy ]] && build arch
  podman image exists "dotfiles-test-$distro:latest" && return 0
  echo ":: building dotfiles-test-$distro"
  podman build -q -t "dotfiles-test-$distro:latest" \
    -f "$here/containers/Containerfile.$distro" "$here/containers" >/dev/null
}

rc=0
for distro in "${distros[@]}"; do
  build "$distro" || { echo ":: build failed: $distro"; rc=1; continue; }
  echo ":: running $distro"
  podman run --rm --name "dotfiles-$distro" \
    -v "$repo":/src:ro,z \
    -v "$here/verify.sh":/verify.sh:ro,z \
    --user armin -e HOME=/home/armin -e USER=armin -e ANSIBLE_ARGS="${extra[*]}" \
    "dotfiles-test-$distro:latest" \
    bash -lc '
      cp -a /src /home/armin/.dotfiles || exit 1
      cd /home/armin/.dotfiles || exit 1
      echo "### bin/dotfiles --detect-os: $(bin/dotfiles --detect-os 2>&1 | tail -1)"
      echo "### login shell before: $(getent passwd armin | cut -d: -f7)"
      ansible-playbook main.yml $ANSIBLE_ARGS
      echo "### ansible-playbook exit: $?"
      bash /verify.sh
    ' || rc=1
done
exit $rc
