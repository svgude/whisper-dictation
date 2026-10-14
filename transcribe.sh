#!/bin/bash
# transcribe.sh <audio.wav> <lang>
# Prints transcribed text to stdout.
# Uses the always-running whisper-server (model stays loaded); falls back to
# whisper-cli if the server is not reachable.
set -e
export PATH="/opt/homebrew/bin:$PATH"

AUDIO="$1"
LANG="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL="$SCRIPT_DIR/models/ggml-large-v3-turbo.bin"
SERVER_URL="http://127.0.0.1:8178/inference"
VOCAB_FILE="$SCRIPT_DIR/vocabulary.txt"

if [ ! -f "$AUDIO" ]; then
  echo "Audio file not found: $AUDIO" >&2
  exit 2
fi

# Vocabulary as initial prompt: "Portfoliobox, CareRouter, ..."
PROMPT=""
if [ -f "$VOCAB_FILE" ]; then
  PROMPT=$(grep -v -e '^#' -e '^[[:space:]]*$' "$VOCAB_FILE" | paste -sd ',' - | sed 's/,/, /g')
  [ -n "$PROMPT" ] && PROMPT="$PROMPT."
fi

clean() {
  tr '\n\t' '  ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

if TEXT=$(curl -sf --max-time 60 "$SERVER_URL" \
    -F file=@"$AUDIO" \
    -F language="$LANG" \
    -F response_format=text \
    -F temperature=0.0 \
    -F prompt="$PROMPT"); then
  printf '%s' "$TEXT" | clean
  exit 0
fi

echo "whisper-server not reachable, falling back to whisper-cli" >&2

if [ ! -f "$MODEL" ]; then
  echo "Model not found: $MODEL. Run install.sh first." >&2
  exit 3
fi

OUT_PREFIX="/tmp/whisper-output-$$"
whisper-cli \
  -m "$MODEL" \
  -l "$LANG" \
  -f "$AUDIO" \
  --prompt "$PROMPT" \
  -nt \
  -otxt \
  -of "$OUT_PREFIX" >/dev/null 2>&1

if [ -f "${OUT_PREFIX}.txt" ]; then
  clean < "${OUT_PREFIX}.txt"
  rm -f "${OUT_PREFIX}.txt"
else
  echo "whisper-cli produced no output" >&2
  exit 4
fi
