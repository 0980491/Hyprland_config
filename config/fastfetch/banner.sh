#!/usr/bin/env bash
# fastfetch with a donut that actually spins.
#
# Bound to `fastfetch` (and `nitch`, and `donut`) in .bashrc. It clears the
# screen, draws the info box with the tumbling torus beside it, and keeps
# turning until you press a key or Ctrl+C. Nothing runs when a terminal opens —
# this only happens when you ask for it.
#
# fastfetch cannot animate: it prints once and exits. So this composes the two
# halves itself — `fastfetch --logo none` gives the box, the frames in
# ~/.config/fastfetch/donut give the torus — and redraws the block in place by
# walking the cursor back up.
#
#   FF_DONUT=0        no animation, plain fastfetch with logo.txt
#   FF_DONUT_SECS=5   stop by itself after 5 seconds (default: never)
#   FF_DONUT_FPS=25   faster (default 15; the frames are ~3.6 degrees apart)
#   FF_DONUT_CLEAR=0  draw where the cursor is instead of clearing the screen
#
# Regenerate or resize the frames with:
#   python3 ~/.config/fastfetch/make-donut.py
set -u

DIR="$HOME/.config/fastfetch/donut"
GAP=3                                   # columns between donut and box
FPS="${FF_DONUT_FPS:-15}"

# `command` because .bashrc aliases fastfetch to this script; an alias would not
# expand inside a script anyway, but this makes it impossible to get wrong.
ff() { command fastfetch "$@"; }

# Anything unusual about the terminal and we just print the static banner:
# the animation walks the cursor by line count, and a wrapped line breaks it.
if [[ "${FF_DONUT:-1}" != "1" || ! -d "$DIR" || ! -t 1 || ! -t 0 || "${TERM:-dumb}" == "dumb" ]]; then
    exec fastfetch
fi

# ── the info box, without a logo; --pipe false keeps the colours ──
mapfile -t INFO < <(ff --logo none --pipe false 2>/dev/null)
(( ${#INFO[@]} )) || exec fastfetch

# Widest info line, colour escapes stripped. wc -L, not ${#var}: the box is
# drawn with multi-byte characters and bash would count bytes, overestimating
# the width by about 28 columns and sending us down the fallback path.
IW=$(printf '%s\n' "${INFO[@]}" | sed 's/\x1b\[[0-9;]*m//g' | wc -L)
(( IW < 20 )) && IW=44

# ── frames ──
mapfile -t FILES < <(find "$DIR" -maxdepth 1 -name '*.txt' | sort)
(( ${#FILES[@]} )) || exec fastfetch

W=0; FH=0
for f in "${FILES[@]}"; do
    mapfile -t lines < "$f"
    (( ${#lines[@]} > FH )) && FH=${#lines[@]}
    for l in "${lines[@]}"; do (( ${#l} > W )) && W=${#l}; done
done

H=$(( FH > ${#INFO[@]} ? FH : ${#INFO[@]} ))
IOFF=$(( (H - ${#INFO[@]}) / 2 ))       # centre the box against the donut

# Not enough room to lay them side by side? Fall back rather than wrap — and
# drop the logo entirely rather than run plain fastfetch, because logo.txt is
# a donut too and would wrap just the same in a narrow window.
COLS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
ROWS=$(tput lines 2>/dev/null || echo 24)
if (( COLS < W + GAP + IW || ROWS < H + 1 )); then
    exec fastfetch --logo none
fi

# ── colour: the same accent matugen gave everything else ──
COLOR=$'\e[1;38;2;255;178;183m'
hex=$(jq -r '.primary // empty' "$HOME/.config/quickshell/colors.json" 2>/dev/null)
if [[ "$hex" =~ ^#([0-9a-fA-F]{6})$ ]]; then
    h=${BASH_REMATCH[1]}
    COLOR=$'\e[1;38;2;'$((16#${h:0:2}))';'$((16#${h:2:2}))';'$((16#${h:4:2}))'m'
fi
RESET=$'\e[0m'

# Compose every frame up front. One run of spaces to slice the padding out of:
# a $(printf '%*s') per line would be 200 frames x 20 lines = 4000 forks before
# the first frame ever showed.
declare -a BLOCK
printf -v SPACES '%*s' "$(( W + GAP ))" ''
for f in "${FILES[@]}"; do
    mapfile -t art < "$f"
    out=""
    for (( i = 0; i < H; i++ )); do
        line="${art[i]:-}"
        info=""
        j=$(( i - IOFF ))
        (( j >= 0 && j < ${#INFO[@]} )) && info="${INFO[j]}"
        out+="${COLOR}${line}${RESET}${SPACES:0:$(( W - ${#line} + GAP ))}${info}"$'\e[K\n'
    done
    BLOCK+=("$out")
done

cleanup() { printf '\e[?25h'; }
trap cleanup EXIT INT TERM

# Clear first so the donut is the only thing on screen. \e[3J drops the
# scrollback too, so scrolling up afterwards is not full of dead frames.
[[ "${FF_DONUT_CLEAR:-1}" == "1" ]] && printf '\e[H\e[2J\e[3J'
printf '\e[?25l'

# No FF_DONUT_SECS means it spins until you stop it.
limit=0
[[ -n "${FF_DONUT_SECS:-}" ]] && limit=$(( FF_DONUT_SECS * FPS ))
delay=$(awk -v f="$FPS" 'BEGIN { printf "%.3f", 1 / f }')

n=0
while :; do
    printf '%s' "${BLOCK[n % ${#BLOCK[@]}]}"
    (( limit > 0 && n >= limit - 1 )) && break
    # doubles as the frame delay and the "any key stops it" check
    if read -rs -t "$delay" -N 1 _skip 2>/dev/null; then break; fi
    printf '\e[%dA' "$H"                # back to the top of the block
    (( n++ ))
done
