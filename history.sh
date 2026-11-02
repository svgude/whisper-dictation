#!/bin/bash
# Prints dictations from the history dictate.lua keeps.
#   ./history.sh      the latest dictation's text, exactly as transcribed
#   ./history.sh 5    the latest five, oldest first, each with its time and language
set -euo pipefail

HISTORY_FILE="$HOME/Library/Application Support/whisper-dictation/history.jsonl"
COUNT="${1:-1}"

if ! [[ "$COUNT" =~ ^[1-9][0-9]*$ ]]; then
  echo "usage: $0 [count]" >&2
  exit 2
fi
if [ ! -s "$HISTORY_FILE" ]; then
  echo "no dictations saved yet ($HISTORY_FILE)" >&2
  exit 1
fi

if [ "$COUNT" -eq 1 ]; then
  tail -n 1 "$HISTORY_FILE" | jq -j '.text'
else
  tail -n "$COUNT" "$HISTORY_FILE" | jq -r '"\(.time) [\(.lang)] \(.text)"'
fi
