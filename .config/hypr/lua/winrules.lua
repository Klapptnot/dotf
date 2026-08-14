local suppressMaximizeRule = hl.window_rule ({
  name           = "suppress-maximize-events",
  match          = { class = ".*" },

  suppress_event = "maximize",
})
suppressMaximizeRule:set_enabled (false)

hl.window_rule ({
  name     = "fix-xwayland-drags",
  match    = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },

  no_focus = true,
})

-- =============================================================================
-- SYSTEM & UI COMPONENTS
-- =============================================================================

hl.layer_rule ({
  name = "wlogout-style",
  match = { namespace = "logout_dialog" },
  blur = true,
  no_anim = true,
})

hl.layer_rule ({
  name = "instant-utility-layers",
  match = { namespace = "(selection|hyprpicker|hyprpaper)" },
  no_anim = true,
})

hl.layer_rule ({
  name = "vicinae-blur",
  match = { namespace = "vicinae" },
  no_anim = true,
  blur = true,
  ignore_alpha = 0,
})

hl.layer_rule ({
  name = "dms-instant",
  match = { namespace = "^(dms:.*)$" },
  no_anim = true,
})

-- =============================================================================
-- WORKFLOW & FILE MANAGEMENT
-- =============================================================================

-- Tagging logic for File Pickers
hl.window_rule ({
  name = "tag-file-picker-portals",
  match = { class = "xdg-desktop-portal-.*" },
  tag = "+choose_file_folder",
})

hl.window_rule ({
  name = "file-picker-layout",
  match = { tag = "choose_file_folder" },
  stay_focused = true,
  float = true,
  move = "((monitor_w*0.25)) ((monitor_h*0.2))",
  size = "(monitor_w*0.5) (monitor_h*0.6)",
})

-- Tagging logic for Thunar Popups
hl.window_rule ({
  name = "tag-thunar-confirmations",
  match = {
    title = "^([Cc]onfirm [Tt]o.*|[Rr]ename.*)$",
    class = "^(thunar)$",
  },
  tag = "+confirm_popup_win",
})

hl.window_rule ({
  name = "thunar-confirmation-layout",
  match = { tag = "confirm_popup_win" },
  stay_focused = true,
  float = true,
  move = "((monitor_w*0.38)) ((monitor_h*0.45))",
  size = "(monitor_w*0.24) (monitor_h*0.1)",
})

-- Progress Tracking (Bottom-Right)
hl.window_rule ({
  name = "tag-operation-progress",
  match = { title = "^(xarchiver|[Ff]ile [Oo]peration.*)$" },
  tag = "+bottom_right_operation",
})

hl.window_rule ({
  name = "operation-progress-layout",
  match = { tag = "bottom_right_operation" },
  float = true,
  no_anim = true,
  no_initial_focus = true,
  move = "((monitor_w*0.74)) ((monitor_h*0.85))",
  size = "(monitor_w*0.24) (monitor_h*0.1)",
})

-- =============================================================================
-- MEDIA & GAMING
-- =============================================================================

hl.window_rule ({
  name = "tag-minecraft-as-game",
  match = { title = "^(Minecraft).*$" },
  tag = "+gamesAny",
})

hl.window_rule ({
  name = "games-tiled-no-idle",
  match = { tag = "gamesAny" },
  idle_inhibit = "focus",
  tile = true,
})

hl.window_rule ({
  name = "tag-picture-in-picture",
  match = { title = "^(Picture[-\\s]?[Ii]n[-\\s]?[Pp]icture).*$" },
  tag = "+pic_in_pic",
})

hl.window_rule ({
  name = "pip-floating-pinned",
  match = { tag = "pic_in_pic" },
  float = true,
  pin = true,
  keep_aspect_ratio = true,
})

-- =============================================================================
-- PRODUCTIVITY & MEETINGS
-- =============================================================================

hl.window_rule ({
  name = "zoom-meeting-focus",
  match = {
    class = "zoom",
    title = "(menu window|Meeting .*)",
  },
  stay_focused = true,
})

hl.window_rule ({
  name = "zoom-no-decorations",
  match = { class = "zoom" },
  decorate = false,
})

hl.window_rule ({
  name = "zoom-floating-elements",
  match = {
    class = "zoom",
    title = "(zoom|Meeting chat|zoom Workplace)",
  },
  float = true,
})

hl.window_rule ({
  name = "jadx-gui-tiling",
  match = {
    class = "jadx-gui-JadxGUI",
    title = "^(.* - jadx-gui)$",
  },
  tile = true,
})

hl.window_rule ({
  name = "fontforge-tiling",
  match = {
    class = "fontforge",
    title = "flameshot",
  },
  tile = true,
})

-- =============================================================================
-- UTILITIES & OVERLAYS
-- =============================================================================

hl.window_rule ({
  name = "battery-alert-urgent",
  match = { class = "xyz.gall.lbagtk" },
  border_size = 0,
  stay_focused = true,
  float = true,
  pin = true,
  no_anim = true,
})

hl.window_rule ({
  name = "gall-pickers-utility",
  match = { class = "xyz.gall.pickers" },
  stay_focused = true,
  float = true,
  pin = true,
  no_anim = true,
})

hl.window_rule ({
  name = "hyprland-keybind-guide",
  match = { title = "^(Hyprland 󰧹 ).*$" },
  float = true,
})

hl.window_rule ({
  name = "flameshot-no-anim",
  match = {
    class = "flameshot",
    title = "flameshot",
  },
  no_anim = true,
})

hl.window_rule ({
  name = "screen-sharing-indicator",
  match = {
    class = "",
    title = "^(.*is sharing (your screen.|a window.))$",
  },
  float = true,
  pin = true,
  no_anim = true,
  decorate = false,
  no_initial_focus = true,
  move = "((monitor_w*0.38)) 5",
})
