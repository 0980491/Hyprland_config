-- ────────────────────────── ENVIRONMENT VARIABLES ───────────────────────────
-- Note: WLR_NO_HARDWARE_CURSORS is gone (it was a wlroots thing). The modern
-- equivalent is cursor.no_hardware_cursors, and on AMD you don't need it.

-- Cursor
-- XCURSOR_THEME is what Hyprland itself draws with, and what XWayland apps
-- resolve against. ~/.config/kcminputrc only covers KDE apps, and gsettings
-- only covers GTK — the theme has to be named in all three places or it looks
-- like "changing the cursor does nothing".
-- Bibata ships as a plain XCursor theme (no manifest.hl), so hyprcursor in
-- look.lua falls back to this automatically.
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Session identity
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- KDE apps build their application catalogue from ${XDG_MENU_PREFIX}applications.menu.
-- Arch only ships /etc/xdg/menus/plasma-applications.menu, and the prefix that points
-- at it is normally exported by startplasma — which never runs here. With the prefix
-- empty, kbuildsycoca6 looked for a plain "applications.menu", found nothing, and
-- indexed zero apps: that is why Dolphin's "Open With" dialog came up completely
-- blank and double-clicking a file never reached the default application.
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Toolkits
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- Without this, Qt only auto-loads the KDE platform theme when
-- XDG_CURRENT_DESKTOP is "KDE" — so under Hyprland every Qt app ignored
-- ~/.config/kdeglobals and came up in the default light palette. Setting it
-- is what makes the Darkly style, the matugen colours and the transparency in
-- ~/.config/darklyrc actually reach Dolphin and friends.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron apps (Discord, VSCode, Zen...) on native Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Java: avoids grey windows on non-reparenting WMs (Arduino IDE, MATLAB...)
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- SDL: you had this forced to x11. Kept, because several native games and
-- emulators behave better through XWayland. To try native Wayland, comment
-- this line out (or set it to "wayland,x11").
hl.env("SDL_VIDEODRIVER", "x11")
