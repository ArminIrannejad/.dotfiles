Dotfiles 

Install:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ArminIrannejad/.dotfiles/master/bin/dotfiles)"
```

Install specific roles only:
```bash
# Neovim only 
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ArminIrannejad/.dotfiles/master/bin/dotfiles)" -- -t neovim

# Neovim and tmux
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ArminIrannejad/.dotfiles/master/bin/dotfiles)" -- -t neovim,tmux
```


Common examples:
```bash
dotfiles                    # Pull latest repo changes and run default_roles
dotfiles -t tmux -vvv       # Run one role with Ansible verbosity
dotfiles --check            # Dry run
dotfiles --list-tags        # List available role tags
dotfiles --uninstall emacs  # Run a role uninstall script, if present
dotfiles --delete old_role  # Uninstall, remove from all.yml, and delete the role directory
```

Supported distributions:

Roles pick their task file from `ansible_facts['distribution']`, so each one has
`tasks/{Ubuntu,Fedora,Archlinux,MacOSX}.yml`. Arch derivatives (CachyOS,
Omarchy, anything with `ID_LIKE=arch`) are normalized to `Archlinux` in
`pre_tasks/normalize_distribution.yml`, so they share the Arch task files.

Testing:
```bash
tests/run.sh                # every distro in a throwaway podman container
tests/run.sh arch fedora    # a subset
tests/run.sh arch -- -t rust  # extra args go to ansible-playbook
```
The images start "dirty" — distro rust/go/neovim pre-installed, stale `.zshrc`
and `.zshenv` in place — so the roles have to displace them. `tests/verify.sh`
asserts the end state.
