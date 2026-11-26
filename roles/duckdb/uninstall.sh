#!/bin/bash
set -e

BIN="${HOME}/.local/bin/duckdb"

if [ -e "$BIN" ] || [ -L "$BIN" ]; then
  __task "Removing duckdb"
  _cmd "rm -f $BIN"
  _task_done
fi
