#!/bin/bash
set -e

if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      for pkg in zoxide; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via apt"
          _cmd "sudo apt-get remove -y $pkg"
          _task_done
        fi
      done
      ;;
    fedora)
      for pkg in zoxide; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via dnf"
          _cmd "sudo dnf remove -y $pkg"
          _task_done
        fi
      done
      ;;
  esac
fi
