#!/usr/bin/env bash

MODE="$1"

if [[ "$MODE" == "ipad" ]]; then
  hyprctl keyword monitor "HDMI-A-1,2160x1620@60.00,3000x3000,2"
elif [[ "$MODE" == "normal" ]]; then
  hyprctl keyword monitor "HDMI-A-1,1920x1080@75.01,-1920x180,1"
else
  echo "Uso: toggle-res.sh [ipad|normal]"
fi
