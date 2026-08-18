#!/usr/bin/env bash

ID="$1"

ENGINE="$HOME/linux-wallpaperengine/build/output/linux-wallpaperengine"

WORKSHOP="$HOME/B/SteamLibrary/steamapps/workshop/content/431960"
ASSETS="$HOME/B/SteamLibrary/steamapps/common/wallpaper_engine/assets"

CACHE="$HOME/Pictures/wallpapers/Current/current.png"

MON1="DP-3"
MON2="HDMI-A-1"
MON3="DP-2"

WALL="$WORKSHOP/$ID"

# Validaciones
[ -z "$ID" ] && echo "Falta ID" && exit 1
[ ! -d "$WALL" ] && echo "Wallpaper ID no encontrado" && exit 1
[ ! -d "$ASSETS" ] && echo "Assets no encontrados" && exit 1

# Matar instancias previas
pkill -f linux-wallpaperengine

"$ENGINE" \
  --assets-dir "$ASSETS" \
  --silent \
  --scaling fill \
  --screen-root "$MON1" --bg "$WALL" &

"$ENGINE" \
  --assets-dir "$ASSETS" \
  --silent \
  --scaling fill \
  --screen-root "$MON2" --bg "$WALL" &

"$ENGINE" \
  --assets-dir "$ASSETS" \
  --silent \
  --scaling fill \
  --screen-root "$MON3" --bg "$WALL" &

sleep 0.5

pkill waybar
sleep 0.2
rm -f "$CACHE"
grim -o "$MON1" "$CACHE"
grim -o "$MON2" "$CACHE"


sleep 0.1
matugen image "$CACHE" --prefer saturation
awww img "$CACHE"
# Recargar componentes
pkill waybar
waybar &

exit 0

