#!/bin/bash
set -e

if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      for pkg in gh; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via apt"
          _cmd "sudo apt-get remove -y $pkg"
          _task_done
        fi
      done
      if [ -f /etc/apt/sources.list.d/github-cli.list ]; then
        __task "Removing GitHub CLI apt repository"
        _cmd "sudo rm -f /etc/apt/sources.list.d/github-cli.list /etc/apt/keyrings/githubcli-archive-keyring.gpg"
        _task_done
      fi
      ;;
    fedora)
      for pkg in gh; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via dnf"
          _cmd "sudo dnf remove -y $pkg"
          _task_done
        fi
      done
      ;;
    arch|archlinux|cachyos)
      for pkg in github-cli; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via pacman"
          _cmd "sudo pacman -R --noconfirm $pkg"
          _task_done
        fi
      done
      ;;
  esac
fi
