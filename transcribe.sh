#!/bin/bash
# transcribe.sh <audio.wav> <lang>
# Prints transcribed text to stdout.
set -e
export PATH="/opt/homebrew/bin:$PATH"

AUDIO="$1"
LANG="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="$SCRIPT_DIR/models/ggml-large-v3-turbo.bin"

if [ ! -f "$AUDIO" ]; then
  echo "Audio file not found: $AUDIO" >&2
  exit 2
fi

if [ ! -f "$MODEL" ]; then
  echo "Model not found: $MODEL. Run install.sh first." >&2
  exit 3
fi

OUT_PREFIX="/tmp/whisper-output-$$"
whisper-cli \
  -m "$MODEL" \
  -l "$LANG" \
  -f "$AUDIO" \
  -nt \
  -otxt \
  -of "$OUT_PREFIX" >/dev/null 2>&1

if [ -f "${OUT_PREFIX}.txt" ]; then
  tr '\n\t' '  ' < "${OUT_PREFIX}.txt" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
  rm -f "${OUT_PREFIX}.txt"
else
  echo "whisper-cli produced no output" >&2
  exit 4
fi
