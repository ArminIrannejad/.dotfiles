#!/bin/bash
set -e

BIN="${HOME}/.local/bin/tuicr"

if [ -e "$BIN" ]; then
  __task "Removing tuicr binary"
  _cmd "rm -f $BIN"
  _task_done
fi
