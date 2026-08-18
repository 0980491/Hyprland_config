-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  Hyprland — Lua config (0.55+)                                           ║
-- ║  Every require() is its own scope: an error in one module does not take   ║
-- ║  the rest of the config down. The old hyprlang config is kept as          ║
-- ║  hyprland.conf.old for reference.                                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

require("conf.env")        -- environment variables
require("conf.monitors")   -- outputs
require("conf.look")       -- gaps, borders, blur, glow, animations
require("conf.input")      -- keyboard, mouse, gestures
require("conf.workspaces") -- workspaces pinned to monitors
require("conf.rules")      -- window and layer rules
require("conf.binds")      -- keybinds
require("conf.autostart")  -- what starts with the session
