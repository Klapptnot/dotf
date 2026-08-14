hl.monitor (
  {
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
  }
)

-- hyprland default
hl.curve ("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve ("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.curve ("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve ("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve ("smoothOut", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
hl.curve ("smoothIn", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve ("easeInBack", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
hl.curve ("easeOutCirc", { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
hl.curve ("peekBack", { type = "bezier", points = { { 0.17, 0.8 }, { 0.95, 0.06 } } })
hl.curve ("peekJump", { type = "bezier", points = { { 0.83, 0.21 }, { 0.09, 0.63 } } })
hl.curve ("peekSlow", { type = "bezier", points = { { 0.15, 0.95 }, { 0.39, 0.36 } } })

hl.animation ({
  leaf = "windows",
  enabled = true,
  speed = 5,
  bezier = "overshot",
  style = "slide",
})
hl.animation ({
  leaf = "windowsIn",
  enabled = true,
  speed = 2,
  bezier = "easeInBack",
  style = "slide",
})
hl.animation ({
  leaf = "windowsOut",
  enabled = true,
  speed = 2,
  bezier = "easeInBack",
  style = "slide",
})
hl.animation ({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "easeOutCirc" })
hl.animation ({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation ({ leaf = "fade", enabled = true, speed = 10, bezier = "smoothIn" })
hl.animation ({
  leaf = "layersIn",
  enabled = true,
  speed = 3,
  bezier = "smoothIn",
  style = "slide",
})
hl.animation ({ leaf = "layersOut", enabled = true, speed = 1.6, bezier = "smoothOut" })
hl.animation ({ leaf = "fadeDim", enabled = true, speed = 10, bezier = "smoothIn" })
hl.animation ({
  leaf = "workspaces",
  enabled = true,
  speed = 2,
  bezier = "smoothIn",
  style = "slide",
})
hl.animation ({
  leaf = "specialWorkspace",
  enabled = true,
  speed = 2,
  bezier = "peekJump",
  style = "fade",
})

-- missing ones
hl.animation ({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation ({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation ({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation ({ leaf = "layers", enabled = true, speed = 3.81, bezier = "peekJump" })
hl.animation ({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation ({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation ({
  leaf = "workspacesIn",
  enabled = true,
  speed = 1.21,
  bezier = "almostLinear",
  style = "fade",
})
hl.animation ({
  leaf = "workspacesOut",
  enabled = true,
  speed = 1.94,
  bezier = "almostLinear",
  style = "fade",
})
hl.animation ({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
