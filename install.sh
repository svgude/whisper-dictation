#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d /Applications/Hammerspoon.app ] && [ ! -d "$HOME/Applications/Hammerspoon.app" ]; then
  echo "==> Hammerspoon not found, installing via Homebrew..."
  brew install --cask hammerspoon
fi

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

VAD_MODEL="$MODELS_DIR/ggml-silero-v6.2.0.bin"
if [ ! -f "$VAD_MODEL" ]; then
  echo "==> Downloading Silero VAD model (~1MB)..."
  curl -L --fail --progress-bar \
    "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin" \
    -o "$VAD_MODEL"
fi

chmod +x "$SCRIPT_DIR/transcribe.sh"

echo "==> Installing whisper-server login agent (keeps the model loaded)..."
AGENT="$HOME/Library/LaunchAgents/net.portfoliobox.whisper-server.plist"
launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
sed "s#__PROJECT_DIR__#$SCRIPT_DIR#g" "$SCRIPT_DIR/net.portfoliobox.whisper-server.plist" > "$AGENT"
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo "==> Linking dictate.lua into Hammerspoon..."
# ~/.hammerspoon only exists once Hammerspoon has been started, so create it
HS_DIR="$HOME/.hammerspoon"
INIT_FILE="$HS_DIR/init.lua"
LINK="$HS_DIR/whisper_dictation.lua"
mkdir -p "$HS_DIR"
touch "$INIT_FILE"
ln -sf "$SCRIPT_DIR/dictate.lua" "$LINK"

if ! grep -q 'require("whisper_dictation")' "$INIT_FILE"; then
  echo '' >> "$INIT_FILE"
  echo 'require("whisper_dictation")' >> "$INIT_FILE"
  echo "==> Added require to init.lua"
fi

if [ ! -f "$LINK" ] || ! grep -q 'require("whisper_dictation")' "$INIT_FILE"; then
  echo "ERROR: Hammerspoon setup failed. Check that $LINK points to" >&2
  echo "       $SCRIPT_DIR/dictate.lua and that $INIT_FILE contains" >&2
  echo '       require("whisper_dictation")' >&2
  exit 1
fi

if pgrep -xq Hammerspoon; then
  RELOAD_STEP="Reload Hammerspoon config (menu bar icon → Reload Config)"
else
  open -g -a Hammerspoon
  RELOAD_STEP="Hammerspoon has been started and loaded the config"
fi

if grep -q 'ctrl_cmd' "$SCRIPT_DIR/local.lua" 2>/dev/null; then
  EN_KEYS="ctrl  + ctrl "
  SV_KEYS="cmd   + cmd  "
  SIRI_NOTE="
  If double-cmd opens Siri, turn off Siri's keyboard shortcut in
  System Settings → Siri (or Apple Intelligence & Siri)."
else
  EN_KEYS="left  shift ×2"
  SV_KEYS="right shift ×2"
  SIRI_NOTE=""
fi

cat <<EOF

==> Done.

FINAL STEPS:
  1. System Settings → Keyboard → Dictation → Shortcut → OFF
     (otherwise macOS dictation can grab the same keys)
  2. $RELOAD_STEP
  3. System Settings → Privacy & Security → Accessibility
     → turn on Hammerspoon (needed to read the keys and paste text)
  4. First time you talk, macOS will ask for microphone permission
     → grant it to Hammerspoon.

USAGE:
  $EN_KEYS → English dictation (again to stop + transcribe)
  $SV_KEYS → Swedish dictation (again to stop + transcribe)
  esc            → cancel recording$SIRI_NOTE
EOF
