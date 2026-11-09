#!/bin/bash
set -e

if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    fedora)
      for pkg in temurin-21-jdk java-25-openjdk-devel java-25-openjdk java-25-openjdk-headless java-25-openjdk-crypto-adapter; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via dnf"
          _cmd "sudo dnf remove -y $pkg"
          _task_done
        fi
      done
      if [ -d /usr/lib/jvm/java-25-openjdk ]; then
        __task "Removing stale OpenJDK 25 files"
        _cmd "sudo rm -rf -- /usr/lib/jvm/java-25-openjdk"
        _task_done
      fi
      ;;
    arch|archlinux|cachyos)
      for pkg in jdk-openjdk; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
          __task "Removing $pkg via pacman"
          _cmd "sudo pacman -R --noconfirm $pkg"
          _task_done
        fi
      done
      ;;
  esac
fi
