#!/bin/bash
set -e

if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      for pkg in python3 python3-pip; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via apt"
          _cmd "sudo apt-get remove -y $pkg"
          _task_done
        fi
      done
      ;;
    fedora)
      for pkg in python3 python3-pip; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via dnf"
          _cmd "sudo dnf remove -y $pkg"
          _task_done
        fi
      done
      ;;
    arch|archlinux|cachyos)
      for pkg in python python-pip; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via pacman"
          _cmd "sudo pacman -R --noconfirm $pkg"
          _task_done
        fi
      done
      ;;
  esac
fi
