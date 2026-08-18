# My Hyprland desktop

Backup and installer for my visual configuration: if I reinstall, move to
another machine or break something, this brings it all back.

Private repository. It is not meant for anyone else, so the paths and the
decisions are mine.

## What is in here

```
config/hypr        Hyprland. Lua config (0.55+), modular:
                     hyprland.lua loads conf/{env,monitors,look,input,
                     workspaces,rules,binds,autostart}
                     hyprlock.conf, hypridle.conf
                     scripts/  (keep-tiled.py among others)
                     legacy/   (hyprpaper, wallpaper-engine, toggle-res)
                     hyprland.conf.old is the old hyprlang config, kept for
                     reference
config/quickshell  My shell: bar, widgets, OSD. scripts/ and unused/
config/rofi        Launcher, themes and scripts (wifi, emoji, clipboard,
                     calculator, keybinds, windows)
config/kitty       Terminal
config/wlogout     Power menu, with its icons
config/fastfetch   Includes the donut and the banner
config/gtk-3.0
config/gtk-4.0     GTK theme, cursor and icons
config/fontconfig
config/xdg-desktop-portal
packages/          What is installed: official repos and AUR, kept separate
```

## Installing on a new machine

```bash
git clone git@github.com:0980491/Hyprland_config.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
./install.sh --dry-run     # see what it would do first
./install.sh
```

Anything already in place is moved to `~/.config/<name>.bak-<timestamp>`
before it is touched. `--link` symlinks to this repository instead of copying,
which is the convenient one if you are going to keep editing the config from
here.

For the packages:

```bash
./install.sh --packages
```

That installs the official-repo ones. The 38 AUR packages (quickshell among
them) need `paru` or `yay`; the script prints the command.

## Deliberately not in here

- **Wallpapers** — 256 MB in `~/Pictures/wallpapers`. Too much for git; they
  travel separately.
- **Cursor and icon themes** — Bibata-Modern-Classic and Papirus-Matugen2.
  They are packages, listed in `packages/`, and I also keep them loose in
  `~/.icons` (32 MB) because Matugen regenerates them.
- **Wallpaper Engine** — not configuration, a separate application.

## Things that are easy to forget and then hurt

- **Absolute paths.** Eleven files carry `/home/ooooooooo` inside them (the
  colour files other configs read, rofi themes, a couple of scripts).
  `install.sh` rewrites those to your `$HOME` when it copies. With `--link` it
  leaves them alone, because it would be editing the repository itself — fix
  them by hand there if your username differs.
- **The Hyprland config is Lua, not hyprlang.** Every `require()` gets its own
  scope, so an error in one module does not take the rest down. Mind one
  consequence: `hyprctl dispatch` is parsed as Lua, and the classic syntax
  (`hyprctl dispatch setfloating address:0x…`) fails. The working form is
  `hyprctl dispatch 'hl.dsp.window.float({ action = "on", window = "address:0x…" })'`.
- **`keep-tiled.py`** watches windows that get floated while being dragged
  across workspaces and puts them back in the layout. It only acts if the left
  mouse button was held down — that is, if it really was a drag. Without that
  check it un-floated any window a rule floated at map time.

## Updating the backup

From the machine that has the good config:

```bash
cd ~/B/hyprland-dotfiles
for d in hypr quickshell kitty rofi wlogout fastfetch gtk-3.0 gtk-4.0 fontconfig xdg-desktop-portal; do
    rm -rf "config/$d" && cp -r "$HOME/.config/$d" config/
done
pacman -Qqe > packages/pacman-explicit.txt
pacman -Qqm > packages/aur-foreign.txt
git add -A && git commit -m "update config" && git push
```
