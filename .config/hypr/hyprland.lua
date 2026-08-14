--- @diagnostic disable: param-type-mismatch
-- Strings may be bash commands by default
debug.getmetatable ("").__call = hl.exec_cmd
string.hprint = function (s)
  hl.notification.create ({ text = s, timeout = 10000 })
end
string.has = function (s, str)
  return string.find (s, str, 1, true) ~= nil
end

--- @type fun(len: integer): string
local function gen_random_string (len)
  math.randomseed (os.time () + math.floor (os.clock () * 1000000))
  local charset =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local t = {}
  for i = 1, len do
    local idx = math.random (#charset)
    t[i] = charset:byte (idx)
  end
  return string.char (table.unpack (t))
end

local notify_dbus = function (title, msg)
  return string.format (
    [[notify send --expire 1000 --app-name Hyprland --icon agave '%s' '%s']],
    string.gsub (title, "'", "'\\''"), string.gsub (msg, "'", "'\\''")
  )
end

--- @param gnome boolean
--- @param ... string
--- @return string
local function systemd_run_cmd (gnome, ...)
  local target_args = { ... }
  local unit_name = "dotf-autostart-" .. gen_random_string (8)

  local systemd_args = {
    "systemd-run",
    "--user",
    "--property=BindsTo=hyprwm.service",
    "--property=After=hyprwm.service",
    "--slice=background-graphical.slice",
    "--unit=" .. unit_name,
  }

  if gnome then
    table.insert (systemd_args, "--setenv=XDG_CURRENT_DESKTOP=GNOME")
    table.insert (systemd_args, "--setenv=XDG_SESSION_DESKTOP=gnome")
  end

  table.insert (systemd_args, "--")
  for _, arg in ipairs (target_args) do
    table.insert (systemd_args, arg)
  end

  return table.concat (systemd_args, " ") .. " &> /dev/null &"
end

hl.on (
  "config.reloaded",
  function ()
    local str = gen_random_string (8)
    if str:has ("miku") then
      notify_dbus (
        "Config reloaded! " .. _VERSION,
        "初音ミクがここにいたー！！🩵"
      ) ()
    end
  end
)

local function on_start ()
  systemd_run_cmd (false, "lbagtk") ()
  systemd_run_cmd (false, "fcitx5") ()
end

hl.on ("hyprland.start", on_start)


require ("lua.config")
require ("lua.keybinds")
require ("lua.monitor")
require ("lua.winrules")
