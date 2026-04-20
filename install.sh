#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing sox and whisper-cpp via Homebrew..."
brew install sox whisper-cpp

MODELS_DIR="$SCRIPT_DIR/models"
MODEL="$MODELS_DIR/ggml-large-v3-turbo.bin"
mkdir -p "$MODELS_DIR"

if [ ! -f "$MODEL" ]; then
  echo ""
  echo "==> Downloading Whisper large-v3-turbo (~1.6GB)..."
  curl -L --fail --progress-bar \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin" \
    -o "$MODEL"
else
  echo "==> Model already downloaded."
fi

chmod +x "$SCRIPT_DIR/transcribe.sh"

HS_DIR="$HOME/.hammerspoon"
ln -sf "$SCRIPT_DIR/dictate.lua" "$HS_DIR/whisper_dictation.lua"

INIT_FILE="$HS_DIR/init.lua"
if ! grep -q 'require("whisper_dictation")' "$INIT_FILE" 2>/dev/null; then
  echo '' >> "$INIT_FILE"
  echo 'require("whisper_dictation")' >> "$INIT_FILE"
  echo "==> Added require to init.lua"
fi

cat <<'EOF'

==> Done.

FINAL STEPS:
  1. System Settings → Keyboard → Dictation → Shortcut → OFF
     (otherwise macOS dictation will conflict with double-Ctrl)
  2. Reload Hammerspoon config (menu bar icon → Reload Config)
  3. First time you talk, macOS will ask for microphone permission
     → grant it to Hammerspoon.

USAGE:
  ctrl + ctrl → English dictation (tap again to stop + transcribe)
  cmd  + cmd  → Swedish dictation (tap again to stop + transcribe)
  esc         → cancel recording
EOF
