-- Whisper Dictation for Hammerspoon
-- ctrl+ctrl → English dictation (tap again to stop + transcribe)
-- cmd+cmd   → Swedish dictation (tap again to stop + transcribe)
-- esc       → abort current recording

local PROJECT_DIR      = "/Users/storg/Developer/whisper-dictation"
local AUDIO_FILE       = "/tmp/whisper-dictation.wav"
local TRANSCRIBE_SCRIPT = PROJECT_DIR .. "/transcribe.sh"
local SOX_BIN          = "/opt/homebrew/bin/sox"
local DOUBLE_TAP_MS    = 300

local recordingTask = nil
local currentLang   = nil
local alertUuid     = nil

local modState = {
  ctrl = { down = false, alone = false, lastTap = 0 },
  cmd  = { down = false, alone = false, lastTap = 0 },
}

local function now_ms()
  return hs.timer.absoluteTime() / 1e6
end

local function showAlert(text)
  if alertUuid then hs.alert.closeSpecific(alertUuid) end
  alertUuid = hs.alert.show(text, 999)
end

local function clearAlert()
  if alertUuid then
    hs.alert.closeSpecific(alertUuid)
    alertUuid = nil
  end
end

local function typeText(text)
  if not text or text == "" then return end
  local prev = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v", 0)
  hs.timer.doAfter(0.3, function()
    if prev then hs.pasteboard.setContents(prev) end
  end)
end

local escHotkey

local function transcribe(lang)
  showAlert("⏳ Transcribing...")
  local task = hs.task.new("/bin/bash",
    function(exitCode, stdout, stderr)
      clearAlert()
      if exitCode == 0 and stdout and stdout:match("%S") then
        local text = stdout:gsub("^%s+", ""):gsub("%s+$", "")
        typeText(text)
      elseif exitCode ~= 0 then
        hs.alert.show("Transcription failed (" .. tostring(exitCode) .. ")")
        print("[whisper] stderr:", stderr)
      else
        hs.alert.show("(empty)")
      end
    end,
    { TRANSCRIBE_SCRIPT, AUDIO_FILE, lang })
  task:start()
end

local function startRecording(lang)
  if recordingTask or currentLang then return end
  currentLang = lang
  local label = (lang == "sv") and "🇸🇪 Spelar in..." or "🇬🇧 Recording..."
  showAlert(label)
  os.remove(AUDIO_FILE)
  recordingTask = hs.task.new(SOX_BIN,
    function(exitCode, stdout, stderr)
      recordingTask = nil
    end,
    { "-d", "-r", "16000", "-c", "1", "-b", "16", AUDIO_FILE })
  if not recordingTask:start() then
    hs.alert.show("Could not start sox (is it installed?)")
    currentLang = nil
    recordingTask = nil
    clearAlert()
    return
  end
  escHotkey:enable()
end

local function stopRecording(doTranscribe)
  if not currentLang then return end
  local lang = currentLang
  currentLang = nil
  escHotkey:disable()
  if recordingTask then
    recordingTask:terminate()
    recordingTask = nil
  end
  clearAlert()
  if doTranscribe then
    hs.timer.doAfter(0.25, function()
      transcribe(lang)
    end)
  end
end

escHotkey = hs.hotkey.new({}, "escape", function()
  stopRecording(false)
  hs.alert.show("❌ Cancelled")
end)

local function handleDoubleTap(mod)
  if currentLang then
    stopRecording(true)
  else
    startRecording(mod == "ctrl" and "en" or "sv")
  end
end

-- Any keyDown while a tracked modifier is held → not a clean tap
local keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  for _, s in pairs(modState) do
    if s.down then s.alone = false end
  end
  return false
end)
keyTap:start()

-- Detect clean double-taps of ctrl or cmd
local flagsTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
  local flags = e:getFlags()
  local t = now_ms()

  local activeCount = 0
  for _, v in pairs(flags) do
    if v then activeCount = activeCount + 1 end
  end

  for modName, s in pairs(modState) do
    local isDown = flags[modName] == true
    if isDown and not s.down then
      s.down = true
      s.alone = (activeCount == 1)
    elseif isDown and s.down then
      if activeCount > 1 then s.alone = false end
    elseif not isDown and s.down then
      s.down = false
      if s.alone then
        if t - s.lastTap < DOUBLE_TAP_MS then
          s.lastTap = 0
          handleDoubleTap(modName)
        else
          s.lastTap = t
        end
      end
    end
  end

  return false
end)
flagsTap:start()

print("[whisper-dictation] loaded")
