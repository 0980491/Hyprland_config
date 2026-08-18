options="\n\n\n"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power" -theme powermenu )
[[ -z "$chosen" ]] && exit 0
confirm=$(echo -e "No\nYes" | rofi -dmenu -p "¿Are you sure?" -theme powermenu )
[[ -z "$chosen" ]] && exit 0
case "$chosen" in
	)
		[[ "$confirm" != "Yes" ]] && exit
		systemctl poweroff
		;;
        )
                [[ "$confirm" != "Yes" ]] && exit
                systemctl reboot
		;;
        )
                [[ "$confirm" != "Yes" ]] && exit
                systemctl suspend
                ;;
        )
                [[ "$confirm" != "Yes" ]] && exit
                hyprlock
                ;;
esac
