#!/bin/bash
set -e

if [ -x "$HOME/.cargo/bin/rustup" ]; then
  __task "Removing rustup toolchains"
  _cmd "$HOME/.cargo/bin/rustup self uninstall -y"
  _task_done
fi
