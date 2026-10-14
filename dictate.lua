-- Whisper Dictation for Hammerspoon
-- Trigger keys are set per machine in local.lua (not committed):
--   return { trigger = "shift" }     -- default
--   return { trigger = "ctrl_cmd" }
--
-- shift:    left-shift ×2 → English, right-shift ×2 → Swedish
-- ctrl_cmd: ctrl ×2       → English, cmd ×2         → Swedish
-- Tap again to stop + transcribe. esc aborts the current recording.

-- Resolve the repo dir through the ~/.hammerspoon symlink
local function projectDir()
  local src = debug.getinfo(1, "S").source:gsub("^@", "")
  local abs = hs.fs.pathToAbsolute(src)
  return abs and abs:match("(.*)/") or (os.getenv("HOME") .. "/Developer/whisper-dictation")
end

local PROJECT_DIR      = projectDir()
local AUDIO_FILE       = "/tmp/whisper-dictation.wav"
local TRANSCRIBE_SCRIPT = PROJECT_DIR .. "/transcribe.sh"
local SOX_BIN          = "/opt/homebrew/bin/sox"
local DOUBLE_TAP_MS    = 300

local localConfig = {}
do
  local ok, cfg = pcall(dofile, PROJECT_DIR .. "/local.lua")
  if ok and type(cfg) == "table" then localConfig = cfg end
end

-- Trigger keys by raw keycode (flagsChanged gives a single flag for both
-- sides of a modifier, so each physical key is tracked on its own).
-- `flag` is the modifier flag the key itself sets, ignored when checking
-- that no other modifier is held.
local TRIGGERS = {
  shift = {
    [56] = { lang = "en", flag = "shift" },  -- left shift
    [60] = { lang = "sv", flag = "shift" },  -- right shift
  },
  ctrl_cmd = {
    [59] = { lang = "en", flag = "ctrl" },   -- left ctrl
    [62] = { lang = "en", flag = "ctrl" },   -- right ctrl
    [55] = { lang = "sv", flag = "cmd" },    -- left cmd
    [54] = { lang = "sv", flag = "cmd" },    -- right cmd
  },
}
local TRIGGER = TRIGGERS[localConfig.trigger or "shift"] or TRIGGERS.shift

local recordingTask = nil
local currentLang   = nil
local pendingLang   = nil  -- language to transcribe once sox has finished writing the file
local alertUuid     = nil

-- Prevent garbage collection of our taps and hotkeys by storing them globally
_G.whisperDictationObjs = {}

local keyState = {}
for kc, key in pairs(TRIGGER) do
  keyState[kc] = { lang = key.lang, flag = key.flag, down = false, alone = false, lastTap = 0 }
end

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
      -- sox stopped by terminate() exits non-zero; only log real failures
      if exitCode ~= 0 and not pendingLang then
        local f = io.open("/tmp/whisper-dictate.log", "a")
        if f then
          f:write(os.date() .. " sox exit=" .. tostring(exitCode) .. " stderr=" .. tostring(stderr) .. "\n")
          f:close()
        end
      end
      -- sox has flushed and closed the wav: transcribe right away
      if pendingLang then
        local l = pendingLang
        pendingLang = nil
        transcribe(l)
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
  _G.whisperDictationObjs.escHotkey:enable()
end

local function stopRecording(doTranscribe)
  if not currentLang then return end
  local lang = currentLang
  currentLang = nil
  _G.whisperDictationObjs.escHotkey:disable()
  clearAlert()
  if doTranscribe then pendingLang = lang end
  if recordingTask and recordingTask:isRunning() then
    -- transcription starts from sox's exit callback
    recordingTask:terminate()
  elseif pendingLang then
    pendingLang = nil
    transcribe(lang)
  end
end

_G.whisperDictationObjs.escHotkey = hs.hotkey.new({}, "escape", function()
  stopRecording(false)
  hs.alert.show("❌ Cancelled")
end)

local function handleDoubleTap(lang)
  if currentLang then
    stopRecording(true)
  else
    startRecording(lang)
  end
end

-- Any keyDown while a trigger key is held → not a clean tap
_G.whisperDictationObjs.keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  for _, s in pairs(keyState) do
    if s.down then s.alone = false end
  end
  return false
end)
_G.whisperDictationObjs.keyTap:start()

-- Detect clean double-taps of a trigger key.
-- flagsChanged fires once per press and once per release; getKeyCode() tells
-- us which physical key changed, and we infer press vs release from our
-- own tracked state (the modifier flag alone can't distinguish sides).
_G.whisperDictationObjs.flagsTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
  local flags = e:getFlags()
  local kc = e:getKeyCode()
  local t = now_ms()

  local s = keyState[kc]
  if s then
    if not s.down then
      s.down = true
      local otherMods = 0
      for fname, v in pairs(flags) do
        if v and fname ~= s.flag then otherMods = otherMods + 1 end
      end
      local otherKeyDown = false
      for kc2, s2 in pairs(keyState) do
        if kc2 ~= kc and s2.down then otherKeyDown = true end
      end
      s.alone = (otherMods == 0 and not otherKeyDown)
      if otherKeyDown then
        for _, s2 in pairs(keyState) do s2.alone = false end
      end
    else
      s.down = false
      if s.alone then
        if t - s.lastTap < DOUBLE_TAP_MS then
          s.lastTap = 0
          handleDoubleTap(s.lang)
        else
          s.lastTap = t
        end
      end
    end
  else
    -- Some other modifier changed while a trigger key is held → not a clean tap
    for _, s2 in pairs(keyState) do
      if s2.down then s2.alone = false end
    end
  end

  return false
end)
_G.whisperDictationObjs.flagsTap:start()

print("[whisper-dictation] loaded, trigger = " .. (localConfig.trigger or "shift"))
