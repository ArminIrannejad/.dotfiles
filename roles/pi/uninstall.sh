#!/bin/bash
set -e

if npm list -g --prefix "$HOME/.local" @earendil-works/pi-coding-agent >/dev/null 2>&1; then
  __task "Removing npm Pi installation"
  _cmd "npm uninstall -g --prefix $HOME/.local @earendil-works/pi-coding-agent"
  _task_done
fi

if command -v pi >/dev/null 2>&1; then
  __task "Removing Pi executable"
  _cmd "rm -f $HOME/.local/bin/pi $HOME/.pi/agent/bin/pi"
  _task_done
fi

if [ -d "$HOME/.pi/agent/install" ]; then
  __task "Removing managed Pi installation"
  _cmd "rm -rf $HOME/.pi/agent/install"
  _task_done
fi

for file in AGENTS.md APPEND_SYSTEM.md; do
  if [ -L "$HOME/.pi/agent/$file" ]; then
    __task "Removing Pi $file symlink"
    _cmd "rm -f $HOME/.pi/agent/$file"
    _task_done
  fi
done

# Keep settings, credentials, package data, and sessions. They may contain
# machine-local state the user still needs after removing the executable.
