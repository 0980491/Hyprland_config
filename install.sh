#!/usr/bin/env bash
# Installs this Hyprland setup into ~/.config.
#
#   ./install.sh                 copy the config, backing up whatever is there
#   ./install.sh --link          symlink to this repo instead of copying
#   ./install.sh --packages      also install the package list (pacman)
#   ./install.sh --dry-run       say what it would do and stop
#
# Backups go to ~/.config/<name>.bak-<timestamp>; nothing is ever overwritten
# without one.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"

MODE="copy"
WITH_PACKAGES=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --link)     MODE="link"; shift ;;
        --packages) WITH_PACKAGES=1; shift ;;
        --dry-run)  DRY_RUN=1; shift ;;
        -h|--help)  sed -n '2,10p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "opción desconocida: $1" >&2; exit 1 ;;
    esac
done

say() { echo "  $*"; }
run() { (( DRY_RUN )) && { say "[dry-run] $*"; return 0; }; "$@"; }

[[ -d "$SRC" ]] || { echo "no encuentro $SRC" >&2; exit 1; }

echo "Instalando en $DEST (modo: $MODE)"

for path in "$SRC"/*; do
    name="$(basename "$path")"
    target="$DEST/$name"

    if [[ -e "$target" || -L "$target" ]]; then
        say "$name: guardo el actual en $name.bak-$STAMP"
        run mv "$target" "$target.bak-$STAMP"
    fi

    if [[ "$MODE" == "link" ]]; then
        say "$name: enlazado a $path"
        run ln -sfn "$path" "$target"
    else
        say "$name: copiado"
        run cp -r "$path" "$target"
    fi
done

# ── Paths with the original username in them ───────────────────────────────
# A handful of files carry absolute paths (colour files that other configs
# read, rofi themes, scripts). On a machine with a different user they would
# silently point nowhere, so rewrite them to this $HOME. Only done when
# copying: rewriting symlinked files would edit the repo itself.
if [[ "$MODE" == "copy" && "$HOME" != "/home/ooooooooo" ]]; then
    echo "Ajustando rutas absolutas a $HOME"
    while IFS= read -r f; do
        say "$(basename "$f")"
        run sed -i "s|/home/ooooooooo|$HOME|g" "$f"
    done < <(grep -rIl "/home/ooooooooo" "$DEST"/{hypr,quickshell,rofi,wlogout} 2>/dev/null)
fi

# ── Packages ───────────────────────────────────────────────────────────────
if (( WITH_PACKAGES )); then
    if ! command -v pacman >/dev/null; then
        echo "pacman no está: instala a mano lo de packages/ (esto es Arch)" >&2
    else
        echo "Instalando paquetes de los repos oficiales"
        run sudo pacman -S --needed --noconfirm - < "$REPO/packages/pacman-explicit.txt"
        echo
        echo "Los de AUR van aparte, con tu ayudante (paru, yay…):"
        echo "  paru -S --needed - < $REPO/packages/aur-foreign.txt"
    fi
fi

cat <<EOF

Hecho. Dos cosas que este repositorio NO trae y hacen falta para que se vea
igual:

  - Fondos de pantalla: no están aquí (son 256 MB). Copia los tuyos a
    ~/Pictures/wallpapers.
  - Tema de cursor e iconos: Bibata-Modern-Classic y Papirus (con el matugen
    encima). Se instalan como paquetes, mira packages/.

Cierra sesión y vuelve a entrar en Hyprland, o recarga con: hyprctl reload
EOF
