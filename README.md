# whisper-dictation

Local dictation on macOS using Whisper (whisper.cpp) and Hammerspoon.
Better quality than macOS built-in dictation, works fully offline.

## Shortcuts

| Keys | Action |
|------|--------|
| left `shift` ×2 | Start/stop English dictation |
| right `shift` ×2 | Start/stop Swedish dictation |
| `esc` | Cancel current recording |

Tap the modifier twice quickly (within 300ms). First tap starts recording,
second tap stops and transcribes. Transcribed text is pasted at the cursor.

To use `ctrl` ×2 (English) and `cmd` ×2 (Swedish) instead, create a
`local.lua` in the repo (not committed, so each machine can differ):

```lua
return { trigger = "ctrl_cmd" }
```

macOS can have Siri on double-tap `cmd`. If so, turn off Siri's keyboard
shortcut (System Settings → Siri), or `cmd` ×2 opens Siri instead.

## Install

Needs [Homebrew](https://brew.sh). Then:

```
./install.sh
```

Installs Hammerspoon too if it's missing (`brew install --cask hammerspoon`).
It doesn't need to have been started before; the script creates
`~/.hammerspoon/` and starts Hammerspoon at the end.

Installs `sox` and `whisper-cpp` via Homebrew, downloads the
`ggml-large-v3-turbo` model (~1.6GB) into `models/`, starts `whisper-server`
as a login agent on `127.0.0.1:8178` (keeps the model in memory, ~1.8GB RAM,
so each dictation takes well under a second instead of ~12s; Silero VAD
drops silence so Whisper doesn't invent text), and symlinks
`dictate.lua` into `~/.hammerspoon/` as `whisper_dictation.lua`.

After install:
1. **Disable macOS dictation shortcut** (System Settings → Keyboard →
   Dictation → Shortcut → Off), otherwise it can grab the same keys.
2. Reload Hammerspoon config (menu bar → Reload Config) if it was already running.
3. **Grant Accessibility** to Hammerspoon (System Settings → Privacy &
   Security → Accessibility). It needs it to read the keys and paste text.
4. Grant microphone permission to Hammerspoon on first run.

## Files

- `dictate.lua` — Hammerspoon config (hotkeys, recording, transcribe orchestration)
- `transcribe.sh` — sends the audio to `whisper-server`; falls back to `whisper-cli` if the server is down
- `net.portfoliobox.whisper-server.plist` — LaunchAgent for the server (log: `/tmp/whisper-server.log`)
- `install.sh` — one-time setup
- `hammerspoon-reference/` — reference copy of the full Hammerspoon config

## Tweaking

`vocabulary.txt` — names and terms Whisper should spell correctly (one per
line). Sent as the initial prompt with every dictation; edits apply at once.

All user-tunable settings are at the top of `dictate.lua`:
- `DOUBLE_TAP_MS` — max ms between taps
- `AUDIO_FILE` — where the temp wav is written
- `SOX_BIN` — path to sox
