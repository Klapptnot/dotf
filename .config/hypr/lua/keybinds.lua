local helpers = require("lua.helpers")

local function bash (s)
  return function ()
    hl.exec_cmd (s)
  end
end

--- @type table<{mapp: string, exec: HL.Dispatcher|fun(), opts: HL.BindOptions}>
local maps
maps = {
  -- --- System & Session ---
  {
    mapp = "META+grave",
    exec = hl.dsp.workspace.toggle_special ("main"),
    opts = { desc = "Toggle special workspace" },
  },
  {
    mapp = "META+SHIFT+grave",
    exec = hl.dsp.window.move ({ workspace = "special:main", follow = true }),
    opts = { desc = "Move current window to special workspace" },
  },
  {
    mapp = "META+L",
    exec = bash ("dms ipc lock lock"),
    opts = { desc = "Lock screen" },
  },
  {
    mapp = "META+SHIFT+Q",
    exec = bash ("dms ipc powermenu toggle"),
    opts = { desc = "Toggle power menu" },
  },
  {
    mapp = "META+F1",
    exec = function () helpers.show_keybinds (maps) end,
    opts = { desc = "Show keybindings menu" },
  },

  -- --- Hardware Controls ---
  {
    mapp = "XF86MonBrightnessUp",
    exec = bash ("dotf dispatch brightness increment 5"),
    opts = { repeating = true, desc = "Increase brightness" },
  },
  {
    mapp = "XF86MonBrightnessDown",
    exec = bash ("dotf dispatch brightness decrement 5"),
    opts = { repeating = true, desc = "Decrease brightness" },
  },
  {
    mapp = "XF86AudioRaiseVolume",
    exec = bash ("dms ipc audio increment 2"),
    opts = { repeating = true, desc = "Raise volume" },
  },
  {
    mapp = "XF86AudioLowerVolume",
    exec = bash ("dms ipc audio decrement 2"),
    opts = { repeating = true, desc = "Lower volume" },
  },
  {
    mapp = "XF86AudioMute",
    exec = bash ("dms ipc audio mute"),
    opts = { locked = true, desc = "Mute audio" },
  },
  {
    mapp = "XF86AudioPlay",
    exec = bash ("playerctl play-pause"),
    opts = { locked = true, desc = "Media play/pause" },
  },
  {
    mapp = "XF86AudioPause",
    exec = bash ("playerctl play-pause"),
    opts = { locked = true, desc = "Media play/pause" },
  },
  {
    mapp = "XF86AudioStop",
    exec = bash ("playerctl stop"),
    opts = { locked = true, desc = "Stop media playback" },
  },
  {
    mapp = "XF86AudioNext",
    exec = bash ("playerctl next"),
    opts = { locked = true, desc = "Next track" },
  },
  {
    mapp = "XF86AudioPrev",
    exec = bash ("playerctl previous"),
    opts = { locked = true, desc = "Previous track" },
  },

  -- --- Screenshots & Recording ---
  {
    mapp = "META+SHIFT+X",
    exec = bash ("wayshot region --extract-text"),
    opts = { desc = "Extract text from region (OCR)" },
  },
  {
    mapp = "META+SHIFT+S",
    exec = bash ("wayshot region"),
    opts = { desc = "Screenshot region" },
  },
  {
    mapp = "ALT+Print",
    exec = bash ("wayshot window"),
    opts = { desc = "Screenshot current window" },
  },
  {
    mapp = "Print",
    exec = bash ("wayshot screen"),
    opts = { locked = true, desc = "Screenshot full screen" },
  },
  {
    mapp = "Pause",
    exec = bash ("dotf-run wfrecord screen -sa @"),
    opts = { desc = "Record region screen area" },
  },

  -- --- Apps ---
  {
    mapp = "ALT+Space",
    exec = bash ("vicinae toggle"),
    opts = { desc = "Toggle app launcher" },
  },
  {
    mapp = "META+Return",
    exec = bash ("dotf-run kitty"),
    opts = { desc = "Launch terminal" },
  },
  {
    mapp = "META+E",
    exec = bash (
      "dotf-run nautilus --new-window"),
    opts = { desc = "Launch file manager" },
  },
  {
    mapp = "META+B",
    exec = bash ("dotf-run www-browser"),
    opts = { desc = "Launch web browser" },
  },

  -- --- Tools & Utilities ---
  {
    mapp = "META+SHIFT+C",
    exec = bash ("hyprpicker -anl"),
    opts = { desc = "Pick screen color" },
  },
  {
    mapp = "META+V",
    exec = bash ("vicinae vicinae://launch/clipboard/history"),
    opts = { desc = "Open clipboard history" },
  },
  {
    mapp = "META+I",
    exec = bash ("dms ipc control-center toggle"),
    opts = { desc = "Toggle process manager window" },
  },
  {
    mapp = "META+O",
    exec = bash ("dms ipc notepad toggle"),
    opts = { desc = "Toggle process manager window" },
  },
  {
    mapp = "META+M",
    exec = bash ("dms ipc processlist focusOrToggle"),
    opts = { desc = "Toggle process manager window" },
  },
  {
    mapp = "META+comma",
    exec = bash ("dms ipc settings focusOrToggle"),
    opts = { desc = "Toggle settings panel layer" },
  },
  {
    mapp = "META+N",
    exec = bash ("dms ipc notifications toggle"),
    opts = { desc = "Toggle notification center" },
  },
  {
    mapp = "META+Y",
    exec = bash ("dms ipc dankdash wallpaper"),
    opts = { desc = "Cycle random wallpaper" },
  },
  {
    mapp = "META+TAB",
    exec = bash ("dms ipc hypr toggleOverview"),
    opts = { desc = "Toggle workspace overview grid" },
  },
  {
    mapp = "META+period",
    exec = bash ("vicinae vicinae://launch/core/search-emojis"),
    opts = { desc = "Open emoji picker" },
  },
  {
    mapp = "META+W",
    exec = bash ("dms ipc bar toggle index 0"),
    opts = { desc = "Toggle primary panel status bar" },
  },
  {
    mapp = "META+ALT+R",
    exec = bash ("rsum | wl-copy"),
    opts = { desc = "Copy random string" },
  },

  -- --- Window Management ---
  {
    mapp = "META+C",
    exec = hl.dsp.window.close (),
    opts = { desc = "Close active window" },
  },
  {
    mapp = "META+ALT+C",
    exec = helpers.close_unfocused,
    opts = { desc = "Close unfocused windows" },
  },
  {
    mapp = "META+K",
    exec = hl.dsp.window.kill(),
    opts = { desc = "Force kill active window process" },
  },
  {
    mapp = "META+ALT+K",
    exec = helpers.kill_unfocused,
    opts = { desc = "Force kill other background processes" },
  },
  {
    mapp = "META+TAB",
    exec = hl.dsp.window.cycle_next (),
    opts = { desc = "Cycle focus to next window" },
  },
  {
    mapp = "META+F",
    exec = hl.dsp.window.fullscreen (),
    opts = { desc = "Toggle window fullscreen mode" },
  },
  {
    mapp = "META+H",
    exec = helpers.fakefullscreen,
    opts = { desc = "Toggle fullscreen sync between client and vm" },
  },
  {
    mapp = "META+T",
    exec = hl.dsp.window.float (),
    opts = { desc = "Toggle window tiling/floating status state" },
  },
  {
    mapp = "META+P",
    exec = hl.dsp.window.pin (),
    opts = { desc = "Toggle pinned-app state" },
  },
  {
    mapp = "META+S",
    exec = hl.dsp.layout ("togglesplit"),
    opts = { desc = "Toggle layout split orientation axis" },
  },

  -- --- Navigation & Positioning ---
  {
    mapp = "META+left",
    exec = hl.dsp.focus ({ direction = "l" }),
    opts = { desc = "Move focus to left" },
  },
  {
    mapp = "META+right",
    exec = hl.dsp.focus ({ direction = "r" }),
    opts = { desc = "Move focus to right" },
  },
  {
    mapp = "META+up",
    exec = hl.dsp.focus ({ direction = "u" }),
    opts = { desc = "Move focus upward" },
  },
  {
    mapp = "META+down",
    exec = hl.dsp.focus ({ direction = "d" }),
    opts = { desc = "Move focus downward" },
  },
  {
    mapp = "META+SHIFT+left",
    exec = hl.dsp.window.move ({ direction = "l" }),
    opts = { desc = "Move current window to the left" },
  },
  {
    mapp = "META+SHIFT+right",
    exec = hl.dsp.window.move ({ direction = "r" }),
    opts = { desc = "Move current window to the right" },
  },
  {
    mapp = "META+SHIFT+up",
    exec = hl.dsp.window.move ({ direction = "u" }),
    opts = { desc = "Move current window upward" },
  },
  {
    mapp = "META+SHIFT+down",
    exec = hl.dsp.window.move ({ direction = "d" }),
    opts = { desc = "Move current window downward" },
  },

  -- --- Resizing ---
  {
    mapp = "META+CTRL+left",
    exec = hl.dsp.window.resize ({ x = -20, y = 0, relative = true }),
    opts = { repeating = true, desc = "Resize -20 to the left" },
  },
  {
    mapp = "META+CTRL+right",
    exec = hl.dsp.window.resize ({ x = 20, y = 0, relative = true }),
    opts = { repeating = true, desc = "Resize +20 to the right" },
  },
  {
    mapp = "META+CTRL+up",
    exec = hl.dsp.window.resize ({ x = 0, y = -20, relative = true }),
    opts = { repeating = true, desc = "Resize -20 upward" },
  },
  {
    mapp = "META+CTRL+down",
    exec = hl.dsp.window.resize ({ x = 0, y = 20, relative = true }),
    opts = { repeating = true, desc = "Resize +20 downward" },
  },
  {
    mapp = "META+mouse:272",
    exec = hl.dsp.window.drag (),
    opts = { desc = "Drag/Move window" },
  },
  {
    mapp = "META+mouse:273",
    exec = hl.dsp.window.resize (),
    opts = { desc = "Resize window" },
  },
}

for wp_id = 1, 10 do
  local map_key = tostring (wp_id % 10)

  table.insert (maps, {
    mapp = "META+" .. map_key,
    exec = function () helpers.named_focus (wp_id) end,
    opts = { desc = "Focus workspace " .. wp_id },
  })

  table.insert (maps, {
    mapp = "META+SHIFT+" .. map_key,
    exec = function () helpers.named_move_window (wp_id) end,
    opts = { desc = "Move window to workspace " .. wp_id },
  })

  table.insert (maps, {
    mapp = "META+ALT+" .. map_key,
    exec = function () helpers.named_swap (wp_id) end,
    opts = { desc = "Swap current workspace with " .. wp_id },
  })
end

for _, map in ipairs (maps) do
  hl.bind (map.mapp, map.exec, map.opts)
end

--- @type HL.GestureSpec[]
local gestures = {
  {
    fingers = 3,
    direction = "vertical",
    action = "special",
    workspace_name = "miku",
  },
  {
    fingers = 3,
    direction = "up",
    mods = "META",
    action = function ()
      local wp = hl.get_workspace ("special:miku")
      if wp == nil then return end
      hl.dispatch (hl.dsp.window.move ({ workspace = wp, follow = true }))
    end,
  },
  {
    fingers = 2,
    direction = "pinchin",
    mods = "META + ALT",
    action = "cursor_zoom",
    zoom_level = 1.5,
    mode = "mult",
  },
  {
    fingers = 2,
    direction = "pinchout",
    mods = "META + ALT",
    action = "cursor_zoom",
    zoom_level = 1,
  },
  {
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
  },
}

for _, g in ipairs (gestures) do
  hl.gesture (g)
end
