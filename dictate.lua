-- Whisper Dictation for Hammerspoon
-- left-shift+left-shift   → English dictation (tap again to stop + transcribe)
-- right-shift+right-shift → Swedish dictation (tap again to stop + transcribe)
-- esc                     → abort current recording

local PROJECT_DIR      = "/Users/minig/Developer/whisper-dictation"
local AUDIO_FILE       = "/tmp/whisper-dictation.wav"
local TRANSCRIBE_SCRIPT = PROJECT_DIR .. "/transcribe.sh"
local SOX_BIN          = "/opt/homebrew/bin/sox"
local DOUBLE_TAP_MS    = 300

local recordingTask = nil
local currentLang   = nil
local alertUuid     = nil

-- Left/right shift are distinguished by raw keycode (flagsChanged gives a
-- single `shift` flag for both, so we track each side independently).
local LSHIFT_KC = 56
local RSHIFT_KC = 60

local shiftState = {
  [LSHIFT_KC] = { name = "lshift", down = false, alone = false, lastTap = 0 },
  [RSHIFT_KC] = { name = "rshift", down = false, alone = false, lastTap = 0 },
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
      if exitCode ~= 0 then
        local f = io.open("/tmp/whisper-dictate.log", "a")
        if f then
          f:write(os.date() .. " sox exit=" .. tostring(exitCode) .. " stderr=" .. tostring(stderr) .. "\n")
          f:close()
        end
      end
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
    startRecording(mod == "lshift" and "en" or "sv")
  end
end

-- Any keyDown while a shift is held → not a clean tap
local keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  for _, s in pairs(shiftState) do
    if s.down then s.alone = false end
  end
  return false
end)
keyTap:start()

-- Detect clean double-taps of left-shift or right-shift.
-- flagsChanged fires once per press and once per release; getKeyCode() tells
-- us which physical shift changed, and we infer press vs release from our
-- own tracked state (the `shift` flag alone can't distinguish sides).
local flagsTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
  local flags = e:getFlags()
  local kc = e:getKeyCode()
  local t = now_ms()

  local otherMods = 0
  for fname, v in pairs(flags) do
    if v and fname ~= "shift" then otherMods = otherMods + 1 end
  end

  local s = shiftState[kc]
  if s then
    if not s.down then
      s.down = true
      local otherShiftDown = false
      for kc2, s2 in pairs(shiftState) do
        if kc2 ~= kc and s2.down then otherShiftDown = true end
      end
      s.alone = (otherMods == 0 and not otherShiftDown)
      if otherShiftDown then
        for _, s2 in pairs(shiftState) do s2.alone = false end
      end
    else
      s.down = false
      if s.alone then
        if t - s.lastTap < DOUBLE_TAP_MS then
          s.lastTap = 0
          handleDoubleTap(s.name)
        else
          s.lastTap = t
        end
      end
    end
  else
    if otherMods > 0 then
      for _, s2 in pairs(shiftState) do
        if s2.down then s2.alone = false end
      end
    end
  end

  return false
end)
flagsTap:start()

print("[whisper-dictation] loaded")
