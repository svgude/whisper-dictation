# whisper-dictation

Local dictation on macOS using Whisper (whisper.cpp) and Hammerspoon.
Better quality than macOS built-in dictation, works fully offline.

## Shortcuts

| Keys | Action |
|------|--------|
| `ctrl` `ctrl` | Start/stop English dictation |
| `cmd` `cmd` | Start/stop Swedish dictation |
| `esc` | Cancel current recording |

Tap the modifier twice quickly (within 300ms). First tap starts recording,
second tap stops and transcribes. Transcribed text is pasted at the cursor.

## Install

```
./install.sh
```

Installs `sox` and `whisper-cpp` via Homebrew, downloads the
`ggml-large-v3-turbo` model (~1.6GB) into `models/`, and symlinks
`dictate.lua` into `~/.hammerspoon/`.

After install:
1. **Disable macOS dictation shortcut** (System Settings → Keyboard →
   Dictation → Shortcut → Off) — otherwise it conflicts with ctrl+ctrl.
2. Reload Hammerspoon config (menu bar → Reload Config).
3. Grant microphone permission to Hammerspoon on first run.

## Files

- `dictate.lua` — Hammerspoon config (hotkeys, recording, transcribe orchestration)
- `transcribe.sh` — runs `whisper-cli` on the audio file
- `install.sh` — one-time setup
- `hammerspoon-reference/` — reference copy of the full Hammerspoon config

## Tweaking

All user-tunable settings are at the top of `dictate.lua`:
- `DOUBLE_TAP_MS` — max ms between taps
- `AUDIO_FILE` — where the temp wav is written
- `SOX_BIN` — path to sox
