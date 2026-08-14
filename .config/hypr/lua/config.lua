local pallete = require ("lua.pallete")

hl.config {
  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },

  general = {
    layout = "dwindle",

    gaps_in = 2,
    gaps_out = 1,

    border_size = 1,

    col = {
      active_border = pallete.border,
      inactive_border = pallete.inactive_border,
      nogroup_border_active = pallete.nogroup_border_active,
      nogroup_border = pallete.nogroup_border,
    },
  },

  input = {
    kb_layout = "us,es",
    kb_variant = "",
    kb_options = "grp:win_space_toggle",
    follow_mouse = 1,
    sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

    touchpad = {
      natural_scroll = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
      scroll_factor = 0.5,
    },
  },

  gestures = {
    workspace_swipe_distance = 700,
    workspace_swipe_cancel_ratio = 0.2,
    workspace_swipe_min_speed_to_force = 5,
    workspace_swipe_direction_lock = true,
    workspace_swipe_direction_lock_threshold = 10,
    workspace_swipe_create_new = true,
  },

  misc = {
    disable_splash_rendering = true,
    mouse_move_enables_dpms = true,

    -- Windows opened from within <regex> replace
    -- and cover (swallow) window <regex>
    enable_swallow = false,
    swallow_regex = "^(kitty)$",

    -- Enforce Hyprland values
    force_default_wallpaper = 1,

    -- Keep natural behavior
    focus_on_activate = true,

    font_family = "Plus Jakarta Sans",
  },

  decoration = {
    rounding = 8,

    active_opacity = 1.0,
    inactive_opacity = 1.0,

    blur = {
      enabled = true,
      size = 1,
      passes = 3,
      new_optimizations = true,
      ignore_opacity = true,
    },

    shadow = {
      enabled = false,
      offset = { 2, 2 },
      range = 4,
      render_power = 2,
      color = pallete.border,
    },
  },

  dwindle = {
    preserve_split = true,
  },

  scrolling = {
    direction = "right",
    follow_focus = true,
    wrap_focus = true,
  },
}

