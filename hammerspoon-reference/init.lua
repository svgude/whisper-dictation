-- ~/.hammerspoon/init.lua
local hk  = hs.hotkey
local key = hs.eventtap.keyStroke
local pb  = hs.pasteboard

-------------------------------------------------
-- Helper: paste exact text (avoids layout issues)
-------------------------------------------------
local function insertText(s)
  local prev = pb.getContents()
  pb.setContents(s)
  key({"cmd"}, "v", 0)
  hs.timer.doAfter(0.15, function()
    if prev then pb.setContents(prev) end
  end)
end

-------------------------------------------------
-- Custom Shortcuts
-------------------------------------------------
-- cmd + 4 → enter / return
hk.bind({"cmd"}, "6", function()
  key({}, ",")
end)

-- cmd + 5 → enter / return
hk.bind({"cmd"}, "7", function()
  key({}, ".")
end)

-- cmd + 8 → delete (backspace)
hk.bind({"cmd"}, "8", function()
  key({}, "delete")
end)

-- cmd + 9 → enter / return
hk.bind({"cmd"}, "9", function()
  key({}, "return")
end)

-- cmd + 7 → dash (-)
hk.bind({"cmd"}, "5", function() insertText("-") end)

-- cmd + shift + - → markdown checkbox
hk.bind({"cmd", "shift"}, "-", function() insertText("- [ ] ") end)

-- cmd + "<" (right of left shift on Swedish layout) → paragraph break (2x enter)
hk.bind({"cmd"}, 50, function()
  key({}, "return", 0)
  key({}, "return", 0)
end)

-------------------------------------------------
-- Scroll: Page Up / Page Down
-------------------------------------------------
hs.hotkey.bind({}, "pageup", function()
  hs.eventtap.scrollWheel({0, 5}, {})
end)

hs.hotkey.bind({}, "pagedown", function()
  hs.eventtap.scrollWheel({0, -5}, {})
end)

require("swedish_fixer")
require("whisper_dictation")
