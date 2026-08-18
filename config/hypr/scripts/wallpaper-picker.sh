#!/usr/bin/env bash
# Wallpaper picker with previews in rofi.
# Mixes plain images and Wallpaper Engine scenes, and can target one monitor.
#
#   wallpaper-picker.sh              → applies to every monitor
#   wallpaper-picker.sh --monitor    → asks which monitor first
set -uo pipefail

WALL="$HOME/.config/hypr/scripts/wallpaper.sh"
ROFI_DIR="$HOME/.config/rofi"
IMG_DIR="$HOME/Pictures/wallpapers"
WS_DIR="$HOME/B/SteamLibrary/steamapps/workshop/content/431960"

MAP="$(mktemp)"; trap 'rm -f "$MAP"' EXIT

MON=""
if [[ "${1:-}" == "--monitor" ]]; then
    MON=$(hyprctl monitors -j | jq -r '.[].name' |
        rofi -dmenu -i -p "Which monitor?" -theme "$ROFI_DIR/themes/list.rasi")
    [[ -z "$MON" ]] && exit 0
fi

we_preview() {
    find "$1" -maxdepth 1 -type f \
        \( -iname 'preview*' -o -iname 'thumbnail*' \) \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) |
        head -n1
}

build_menu() {
    printf '\0message\x1fWallpaper%s — Enter applies\n' "${MON:+ → <b>$MON</b>}"

    printf '󰑙  Random\0icon\x1fmedia-playlist-shuffle\n'
    printf '󰅖  Remove wallpaper\0icon\x1fedit-delete\n'
    [[ -z "$MON" ]] && printf '󰍹  Pick per monitor…\0icon\x1fvideo-display\n'

    # Static images
    while read -r img; do
        [[ -z "$img" ]] && continue
        local label="󰋩  $(basename "$img")"
        printf '%s\tIMG\t%s\n' "$label" "$img" >> "$MAP"
        printf '%s\0icon\x1f%s\n' "$label" "$img"
    done < <(find "$IMG_DIR" -maxdepth 1 -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) | sort)

    # Wallpaper Engine
    while read -r dir; do
        [[ -z "$dir" ]] && continue
        local id title prev label
        id="$(basename "$dir")"
        title="$(jq -r '.title // empty' "$dir/project.json" 2>/dev/null)"
        [[ -z "$title" ]] && title="$id"
        label="󰕧  $title"
        # if two scenes share a title, disambiguate with the id
        grep -qF "$label	" "$MAP" 2>/dev/null && label="$label ($id)"
        printf '%s\tWE\t%s\n' "$label" "$id" >> "$MAP"
        prev="$(we_preview "$dir")"
        if [[ -n "$prev" ]]; then
            printf '%s\0icon\x1f%s\n' "$label" "$prev"
        else
            printf '%s\n' "$label"
        fi
    done < <(find "$WS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
}

SEL=$(build_menu | rofi -dmenu -i -show-icons -p "Wallpaper" \
        -theme "$ROFI_DIR/themes/grid.rasi") || exit 0
[[ -z "$SEL" ]] && exit 0

case "$SEL" in
    *"Random")            exec "$WALL" random "$MON" ;;
    *"Remove wallpaper")  exec "$WALL" off ;;
    *"Pick per monitor…") exec "$0" --monitor ;;
esac

LINE=$(grep -F "$SEL	" "$MAP" | head -1)
KIND=$(cut -f2 <<< "$LINE")
VALUE=$(cut -f3 <<< "$LINE")

case "$KIND" in
    IMG) exec "$WALL" image "$VALUE" "$MON" ;;
    WE)  exec "$WALL" we    "$VALUE" "$MON" ;;
    *)   exit 0 ;;
esac
