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
