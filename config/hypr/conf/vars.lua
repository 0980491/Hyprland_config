-- Programs and paths shared across modules.
local M = {}

M.terminal     = "kitty"
M.fileManager  = "dolphin"
M.browser      = "zen-browser"

M.scripts      = os.getenv("HOME") .. "/.config/hypr/scripts"
M.rofiScripts  = os.getenv("HOME") .. "/.config/rofi/scripts"

M.launcher     = M.rofiScripts .. "/launcher.sh"
M.clipboard    = M.rofiScripts .. "/clipboard.sh"
M.emoji        = M.rofiScripts .. "/emoji.sh"
M.wifi         = M.rofiScripts .. "/wifi.sh"
M.bluetooth    = M.rofiScripts .. "/bluetooth.sh"
M.windows      = M.rofiScripts .. "/windows.sh"
M.powermenu    = M.rofiScripts .. "/powermenu.sh"
M.keybinds     = M.rofiScripts .. "/keybinds.sh"

M.wallpaper    = M.scripts .. "/wallpaper.sh"
M.wallPicker   = M.scripts .. "/wallpaper-picker.sh"
M.screenshot   = M.scripts .. "/screenshot.sh"
M.gamemode     = M.scripts .. "/gamemode.sh"

return M
