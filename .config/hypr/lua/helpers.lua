local main = {}

local names = {
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "ten",
}

-- local ordered_modifiers = {
--   { bit = 16,  name = "MOD2" },
--   { bit = 32,  name = "MOD3" },
--   { bit = 64,  name = "META" },
--   { bit = 128, name = "MOD5" },
--   { bit = 1,   name = "SHIFT" },
--   { bit = 2,   name = "CAPS" },
--   { bit = 4,   name = "CTRL" },
--   { bit = 8,   name = "ALT" },
-- }
--
-- local function unmask (mask)
--   local active = {}
--
--   for _, mod in ipairs (ordered_modifiers) do
--     if (mask & mod.bit) ~= 0 then
--       table.insert (active, mod.name)
--     end
--   end
--
--   return active
-- end

local function get_name_param (f)
  if not debug then return "Unknown" end
  local name, value = debug.getupvalue (f, 2)
  if type(name) == "string" and name == "s" then return value end
  return "Unknown"
end

function main.named_focus(wp_id)
  local wp = hl.get_workspace("name:" .. names[wp_id])
  if wp ~= nil then
    hl.dispatch(hl.dsp.focus({ workspace = wp }))
    return
  end

  hl.dispatch(hl.dsp.focus({ workspace = wp_id }))
  hl.dispatch(hl.dsp.workspace.rename({
    workspace = wp_id,
    name = names[wp_id],
  }))
end

function main.named_move_window(wp_id, follow)
  follow = follow or true
  local wp = hl.get_workspace("name:" .. names[wp_id])
  if wp ~= nil then
    hl.dispatch(hl.dsp.window.move({ workspace = wp, follow = follow }))
    return
  end

  hl.dispatch(hl.dsp.window.move({ workspace = wp_id, follow = follow }))
  hl.dispatch(hl.dsp.workspace.rename({
    workspace = wp_id,
    name = names[wp_id],
  }))
end

function main.named_swap(wp_id)
  local wp = hl.get_workspace("name:" .. names[wp_id])
  if wp == nil then return end -- Target is empty, skip

  local curr = hl.get_active_workspace()
  if curr == nil then return end

  hl.dispatch(hl.dsp.workspace.rename({
    workspace = wp_id,
    name = names[curr.id],
  }))
  hl.dispatch(hl.dsp.workspace.rename({
    workspace = curr.id,
    name = names[wp_id],
  }))
end

--- @param dsp fun(any...):HL.Dispatcher
local function dispatch_on_unfocused (dsp)
  local clients = hl.get_windows ()
  local active_ws = hl.get_active_workspace ()

  if clients and active_ws then
    for _, client in ipairs (clients) do
      if client.workspace.id == active_ws.id and client.focus_history_id ~= 0 then
        hl.dispatch (dsp ({ window = "address:" .. client.address }))
      end
    end
  end
end

function main.fakefullscreen ()
  local win = hl.get_active_window ()
  if win ~= nil then
    local next_client_state = win.fullscreen_client == 2 and 0 or 2

    hl.dispatch (hl.dsp.window.fullscreen_state ({
      internal = win.fullscreen,
      client = next_client_state,
    }))
  end
end

function main.close_unfocused ()
  dispatch_on_unfocused (hl.dsp.window.close)
end

function main.kill_unfocused ()
  dispatch_on_unfocused (hl.dsp.window.kill)
end

function main.show_keybinds (bindings)
  local monitor = hl.get_active_monitor ()
  if monitor == nil then return end

  local scale = monitor.scale
  local width = math.floor ((monitor.width / scale) + 0.9)
  local height = math.floor ((monitor.height / scale) + 0.9)

  local max_width = 1200
  local max_height = 1000

  local d_width = math.floor (width * 0.7)
  local d_height = math.floor (height * 0.7)

  if d_width > max_width then d_width = max_width end
  if d_height > max_height then d_height = max_height end

  local yad_args = {
    "yad",
    "--width",
    tostring (d_width),
    "--height",
    tostring (d_height),
    "--center",
    "--on-top",
    string.format ("--title='Hyprland 󰧹  %d'", #bindings),
    "--no-buttons",
    "--list",
    "--column=Mods",
    "--column=Key",
    "--column=Description",
    "--column=Args",
    "--",
  }

  for _, val in ipairs (bindings) do
    local mod, key = string.match (val.mapp, "^(.*)%+([^%+]*)")
    table.insert (yad_args, mod or "''")
    table.insert (yad_args, key or val.mapp)
    table.insert (yad_args, string.format ("'%s'", val.opts.desc))
    if type (val.exec) == "function" then
      table.insert (yad_args, string.format ("'%s'", get_name_param (val.exec)))
    else
      table.insert (yad_args, string.format ("'%s'", val.exec))
    end
  end

  hl.exec_cmd (table.concat (yad_args, " "))
end

return main
