#!/bin/bash
set -e

if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    fedora)
      for pkg in java-25-openjdk; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via dnf"
          _cmd "sudo dnf remove -y $pkg"
          _task_done
        fi
      done
      ;;
  esac
fi
