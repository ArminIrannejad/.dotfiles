#!/bin/bash
set -e

DIR="${HOME}/.local/share/sqlcl"
BIN="${HOME}/.local/bin/sql"

if [ -L "$BIN" ]; then
  __task "Removing sql symlink"
  _cmd "rm -f $BIN"
  _task_done
fi

if [ -d "$DIR" ]; then
  __task "Removing sqlcl"
  _cmd "rm -rf $DIR"
  _task_done
fi
