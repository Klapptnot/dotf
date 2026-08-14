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

local function show_window (bindings)
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
    table.insert (yad_args, string.format ("'%s'", val.exec))
  end

  hl.exec_cmd (table.concat (yad_args, " "))
end

return show_window
