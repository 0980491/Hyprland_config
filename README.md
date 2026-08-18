# Mi escritorio de Hyprland

Copia de seguridad y de instalación de mi configuración visual: si formateo,
cambio de máquina o rompo algo, esto la devuelve entera.

Repositorio privado. No está pensado para nadie más, así que las rutas y las
decisiones son las mías.

## Qué hay dentro

```
config/hypr        Hyprland. Configuración en Lua (0.55+), modular:
                     hyprland.lua carga conf/{env,monitors,look,input,
                     workspaces,rules,binds,autostart}
                     hyprlock.conf, hypridle.conf
                     scripts/  (keep-tiled.py entre otros)
                     legacy/   (hyprpaper, wallpaper-engine, toggle-res)
                     hyprland.conf.old es la configuración vieja en hyprlang,
                     guardada como referencia
config/quickshell  Mi shell: barra, widgets, OSD. scripts/ y unused/
config/rofi        Lanzador, temas y scripts (wifi, emoji, portapapeles,
                     calculadora, keybinds, ventanas)
config/kitty       Terminal
config/wlogout     Menú de apagado, con sus iconos
config/fastfetch   Incluye el donut y el banner
config/gtk-3.0
config/gtk-4.0     Tema GTK, cursor e iconos
config/fontconfig
config/xdg-desktop-portal
packages/          Lo que hay instalado: repos oficiales y AUR por separado
```

## Instalar en una máquina nueva

```bash
git clone git@github.com:0980491/REPO.git ~/hyprland-dotfiles
cd ~/hyprland-dotfiles
./install.sh --dry-run     # mira primero qué va a hacer
./install.sh
```

Guarda lo que ya hubiera en `~/.config/<nombre>.bak-<fecha>` antes de tocar
nada. Con `--link` enlaza a este repositorio en vez de copiar, que es lo
cómodo si vas a seguir editando la configuración desde aquí.

Para los paquetes:

```bash
./install.sh --packages
```

Instala los de los repos oficiales. Los de AUR (38, entre ellos quickshell)
hay que pasarlos por `paru` o `yay`, el script te dice cómo.

## Lo que NO está aquí, a propósito

- **Fondos de pantalla** — 256 MB en `~/Pictures/wallpapers`. Demasiado para
  git; van aparte.
- **Temas de cursor e iconos** — Bibata-Modern-Classic y Papirus-Matugen2.
  Son paquetes, están en `packages/`, y los tengo también sueltos en
  `~/.icons` (32 MB) porque Matugen los regenera.
- **Wallpaper Engine** — no es configuración, es una aplicación aparte.

## Detalles que se olvidan y luego duelen

- **Rutas absolutas.** Once ficheros llevan `/home/ooooooooo` dentro (los
  ficheros de color que otras configuraciones leen, temas de rofi, algún
  script). `install.sh` los reescribe a tu `$HOME` cuando copia. Si instalas
  con `--link` no los toca, porque editaría el repositorio: en ese caso
  ajústalos a mano si tu usuario es otro.
- **La configuración de Hyprland es Lua, no hyprlang.** Cada `require()` va en
  su propio ámbito, así que un error en un módulo no tumba el resto. Ojo con
  una consecuencia: `hyprctl dispatch` se interpreta como Lua, y la sintaxis
  clásica (`hyprctl dispatch setfloating address:0x…`) falla. La forma buena
  es `hyprctl dispatch 'hl.dsp.window.float({ action = "on", window = "address:0x…" })'`.
- **`keep-tiled.py`** vigila las ventanas que se flotan al arrastrarlas entre
  workspaces y las devuelve al layout. Solo actúa si el botón izquierdo del
  ratón estaba pulsado, o sea si fue un arrastre de verdad: sin esa
  comprobación destilaba cualquier ventana que una regla flotara al abrirse.

## Actualizar la copia

Desde la máquina que tiene la configuración buena:

```bash
cd ~/B/hyprland-dotfiles
for d in hypr quickshell kitty rofi wlogout fastfetch gtk-3.0 gtk-4.0 fontconfig xdg-desktop-portal; do
    rm -rf "config/$d" && cp -r "$HOME/.config/$d" config/
done
pacman -Qqe > packages/pacman-explicit.txt
pacman -Qqm > packages/aur-foreign.txt
git add -A && git commit -m "actualiza la config" && git push
```
