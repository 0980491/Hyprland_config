#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Wallpapers: images (awww) + Wallpaper Engine, with Material You theming  ║
# ║                                                                          ║
# ║  What changed from the old script:                                       ║
# ║   · ONE linux-wallpaperengine process for every monitor                   ║
# ║   · monitors detected at runtime (they used to be hardcoded)              ║
# ║   · colours come from --screenshot: no grim, no killing the bar           ║
# ║   · FPS cap and automatic pause while a game is fullscreen                ║
# ║   · per-monitor wallpapers, and the state survives a reboot               ║
# ║   · each scene's still and palette are kept, so it is captured once       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
set -uo pipefail

IMG_DIR="$HOME/Pictures/wallpapers"
WS_DIR="$HOME/B/SteamLibrary/steamapps/workshop/content/431960"
WE_ASSETS="$HOME/B/SteamLibrary/steamapps/common/wallpaper_engine/assets"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
STATE="$STATE_DIR/wallpaper.json"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper"
WE_SHOT="$CACHE_DIR/we-shot.png"
CURRENT="$IMG_DIR/Current/current.png"   # used by hyprlock and the shell

# Per-scene cache. W holds the still we captured for a Wallpaper Engine scene,
# M holds the palette we pulled out of it. Both are keyed by the workshop id, so
# a scene that is already in here costs no screenshot and no image analysis: the
# capture is the expensive part (Wallpaper Engine has to render and dump a
# 2560x1440 frame, and the script blocks up to 15 s waiting for it).
CACHE_ROOT="${WALL_CACHE_ROOT:-$HOME/General/Photos/Wallpaper-en}"
W_DIR="$CACHE_ROOT/W"
M_DIR="$CACHE_ROOT/M"
SHOT_QUALITY="${WALL_SHOT_QUALITY:-95}"  # JPEG quality for the cached stills
IMG_EXTS='jpg|jpeg|png|webp'

WE_FPS="${WE_FPS:-60}"                   # 165 fps on a background is wasted GPU
WE_VOLUME="${WE_VOLUME:-0}"              # 0 = muted
# Frames to let a scene run before the screenshot. Too few and the capture is
# whatever was in the framebuffer — noise, or a scene still fading in. Only
# matters the first time a scene is seen, so being generous is cheap now.
WE_SHOT_DELAY="${WE_SHOT_DELAY:-45}"

mkdir -p "$STATE_DIR" "$CACHE_DIR" "$(dirname "$CURRENT")" "$W_DIR" "$M_DIR"
# An empty or half-written state file is worse than no state file at all: jq
# reads nothing out of it, prints nothing and still exits 0, so every st_set
# writes another empty file on top of it and the wallpaper never comes back —
# `restore` doesn't even reach its fallback, because ".monitors | length" comes
# out as "" instead of "0". Anything that isn't valid JSON gets rebuilt.
jq -e . "$STATE" >/dev/null 2>&1 || echo '{"monitors":{},"theme":null}' > "$STATE"

# ───────────────────────────────── helpers ──────────────────────────────────
log() { printf '\e[38;5;214m[wallpaper]\e[0m %s\n' "$*" >&2; }

notify() {
    command -v notify-send >/dev/null && notify-send -a "Wallpaper" -t 2500 "$1" "${2:-}" || true
}

monitors() { hyprctl monitors -j | jq -r '.[].name'; }

# The monitor everything is themed from: its wallpaper is what feeds matugen,
# hyprlock and the rofi launcher. Defaults to the biggest one (yours is DP-3);
# override with WALL_MAIN=HDMI-A-1 if you ever want the other.
main_monitor() {
    [[ -n "${WALL_MAIN:-}" ]] && { echo "$WALL_MAIN"; return; }
    hyprctl monitors -j | jq -r 'sort_by(.width * .height) | last | .name'
}

st() { jq -r "$1" "$STATE" 2>/dev/null; }

# Never let an empty result land on the state file (see the jq -e guard above):
# a filter that produced nothing means the state we read was already broken, and
# overwriting it would lose the wallpapers for good.
st_put() {
    local tmp="$1"
    if [[ -s "$tmp" ]]; then mv "$tmp" "$STATE"; else rm -f "$tmp"; log "state update produced nothing, keeping the old file"; return 1; fi
}

st_set() {
    local tmp; tmp="$(mktemp)"
    jq "$1" "$STATE" > "$tmp" && st_put "$tmp"
}

# Same, but for a value that is a string: cached stills are named after the
# scene title, and a title with a quote in it would break jq if it were pasted
# straight into the filter.
st_set_str() {
    local tmp; tmp="$(mktemp)"
    jq --arg v "$2" "$1 = \$v" "$STATE" > "$tmp" && st_put "$tmp"
}

we_title() {
    local id="$1" pj="$WS_DIR/$id/project.json"
    [[ -f "$pj" ]] && jq -r '.title // empty' "$pj" 2>/dev/null || echo "$id"
}

# Wallpaper Engine ships a still frame next to each scene; that is what the
# picker shows, since a scene has nothing else to preview.
we_preview() {
    find "$1" -maxdepth 1 -type f \
        \( -iname 'preview*' -o -iname 'thumbnail*' \) \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) |
        head -n1
}

# The process name is longer than 15 chars, so pgrep/pkill -x won't match it.
# The [l]inux-... pattern keeps pkill from killing itself.
we_running() { pgrep -f '[l]inux-wallpaperengine' >/dev/null; }
we_stop()    { pkill -f '[l]inux-wallpaperengine' 2>/dev/null; sleep 0.3; }

# The scene the palette is built from: the main monitor's, or the first one
# there is if the main monitor isn't running a scene. Same order we_start walks,
# so this always names the scene the screenshot would have come from.
theme_we_id() {
    local main m id
    main="$(main_monitor)"
    for m in "$main" $(monitors); do
        [[ -z "$m" ]] && continue
        id="$(st ".monitors[\"$m\"] | select(.type==\"we\") | .id")"
        [[ -n "$id" && "$id" != "null" ]] && { printf '%s' "$id"; return 0; }
    done
    return 1
}

# ───────────────────────── per-scene cache (W and M) ────────────────────────
# Entries are named "<id>" or "<id> — <title>", with an image extension in W and
# .json in M. The title is only there so the folders are readable when you
# browse them: everything is looked up by the id in front, which is why a file
# you drop in yourself only has to be called "<id>.jpg".
cache_find() {
    local dir="$1" id="$2" exts="${3:-$IMG_EXTS}" re f
    re="\.($exts)$"
    for f in "$dir/$id".* "$dir/$id "*; do
        [[ -f "$f" ]] || continue
        [[ "${f,,}" =~ $re ]] || continue
        printf '%s' "$f"; return 0
    done
    return 1
}

cache_name() {
    local id="$1" t
    # The result is a filename, it goes into the state file, and Quickshell
    # builds a file:// URL out of it — so quotes, backslashes and the characters
    # that mean something in a URL all come out.
    t="$(we_title "$id" | tr -d '\000-\037"\\#?%' | tr '/' '-' |
         sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$t" || "$t" == "$id" ]] && { printf '%s' "$id"; return; }
    printf '%s — %s' "$id" "${t:0:80}"
}

# Every entry for an id, whatever it happens to be named.
cache_drop() {
    local id="$1" f
    for f in "$W_DIR/$id".* "$W_DIR/$id "* "$M_DIR/$id".* "$M_DIR/$id "*; do
        [[ -f "$f" ]] && rm -f "$f"
    done
    return 0
}

# Keep the capture so this scene never has to be screenshotted again. JPEG,
# because the stills are the size of the monitor and there are 100+ scenes.
# Prints the path it wrote.
cache_save_shot() {
    local id="$1" src="$2" dest f
    [[ -s "$src" ]] || return 1
    dest="$W_DIR/$(cache_name "$id").jpg"
    # An older entry could be sitting under a different title (the scene got
    # renamed in the workshop), and two files for one id would be ambiguous.
    for f in "$W_DIR/$id".* "$W_DIR/$id "*; do [[ -f "$f" ]] && rm -f "$f"; done
    if command -v magick >/dev/null; then
        magick "$src" -quality "$SHOT_QUALITY" "$dest" 2>/dev/null ||
            { log "could not write $dest"; return 1; }
    else
        dest="${dest%.jpg}.png"
        cp -f "$src" "$dest" || return 1
    fi
    log "still cached: ${dest#"$CACHE_ROOT"/}"
    printf '%s' "$dest"
}

# Read the source colour off an image and file it under M. --dry-run means
# matugen only reports the colour here and renders nothing; the templates are
# built later from that same colour. Checked: `matugen color hex <source>`
# produces byte-identical `colors` and `palettes` to `matugen image` — only the
# base16 block differs, and none of our templates read base16.
cache_save_palette() {
    local id="$1" img="$2" color dest f
    color="$(matugen image "$img" --prefer saturation --json hex --dry-run 2>/dev/null |
             jq -r '.colors.source_color.default.color // empty' 2>/dev/null)"
    [[ -n "$color" ]] || { log "matugen could not read a colour off $img"; return 1; }
    dest="$M_DIR/$(cache_name "$id").json"
    for f in "$M_DIR/$id".* "$M_DIR/$id "*; do [[ -f "$f" ]] && rm -f "$f"; done
    jq -n --arg id "$id" --arg title "$(we_title "$id")" --arg source "$color" \
          --arg from "$(basename "$img")" --arg saved "$(date -Is)" \
        '{ id: $id, title: $title, source: $source,
           mode: "dark", type: "scheme-tonal-spot",
           from: $from, saved: $saved }' > "$dest" || return 1
    log "palette cached: $color"
    printf '%s' "$color"
}

# ──────────────────────────── Wallpaper Engine ──────────────────────────────
# we_start [capture]  —  capture=0 skips --screenshot entirely, which is the
# whole point of the cache: no render-and-dump inside Wallpaper Engine, no
# 15-second wait here, no ImageMagick crop afterwards.
we_start() {
    local capture="${1:-1}" shot_for="" args=() main
    main="$(main_monitor)"
    args+=(--assets-dir "$WE_ASSETS" --fps "$WE_FPS" --scaling fill)
    # --silent mutes, but the process still keeps a Stream/Output/Audio node
    # wired into the same PipeWire graph as the speakers. Taking it out is done
    # with the WirePlumber rule in ~/.config/wireplumber/wireplumber.conf.d/,
    # not with --no-audio-processing: that flag only turns off the analysis that
    # makes audio-reactive scenes pulse to whatever is playing, and it does not
    # remove the node anyway (tested).
    [[ "$WE_VOLUME" == "0" ]] && args+=(--silent) || args+=(--volume "$WE_VOLUME")
    # Pause the background only while the fullscreen game is focused, so the
    # wallpaper on the other monitor keeps running.
    args+=(--fullscreen-pause-only-active)

    # Main monitor first: linux-wallpaperengine lays the screenshot out in the
    # order the --screen-root arguments are given, so putting it first means its
    # part of the capture always starts at 0,0.
    local ordered=()
    [[ -n "$main" ]] && ordered+=("$main")
    while read -r m; do
        [[ -z "$m" || "$m" == "$main" ]] && continue
        ordered+=("$m")
    done < <(monitors)

    local any=0 mon id
    for mon in "${ordered[@]}"; do
        [[ -z "$mon" ]] && continue
        id="$(st ".monitors[\"$mon\"] | select(.type==\"we\") | .id")"
        [[ -z "$id" || "$id" == "null" ]] && continue
        [[ -d "$WS_DIR/$id" ]] || { log "id $id is not in the workshop, skipping"; continue; }
        # only the main monitor feeds the palette
        if [[ "$mon" == "$main" ]]; then
            shot_for="$mon"
            if [[ "$capture" == "1" ]]; then
                rm -f "$WE_SHOT"
                args+=(--screenshot "$WE_SHOT" --screenshot-delay "$WE_SHOT_DELAY")
            fi
        fi
        args+=(--screen-root "$mon" --bg "$WS_DIR/$id")
        any=1
    done

    [[ $any -eq 0 ]] && return 1

    # main monitor isn't running a scene? fall back to whichever one is
    if [[ -z "$shot_for" && "$capture" == "1" ]]; then
        rm -f "$WE_SHOT"
        args+=(--screenshot "$WE_SHOT" --screenshot-delay "$WE_SHOT_DELAY")
        shot_for="fallback"
    fi

    log "starting wallpaper engine (${WE_FPS} fps)"
    # 9>&- so the wallpaper does not inherit refresh's lock file descriptor. It
    # outlives the script that started it, and while it held that descriptor the
    # lock was never released: every later refresh saw "one is already pending"
    # and returned without doing anything, which is the whole point of it.
    setsid linux-wallpaperengine "${args[@]}" \
        >"$CACHE_DIR/we.log" 2>&1 < /dev/null 9>&- &
    disown

    # Wait for the screenshot so we can derive the palette (15 s max)
    if [[ -n "$shot_for" && "$capture" == "1" ]]; then
        local i
        for i in $(seq 1 60); do
            [[ -s "$WE_SHOT" ]] && sleep 0.4 && return 0
            sleep 0.25
        done
        log "screenshot took too long; keeping the previous palette"
        return 2
    fi
    return 0
}

# ─────────────────────────────── images (awww) ──────────────────────────────
awww_ready() { awww query >/dev/null 2>&1 || { awww-daemon >/dev/null 2>&1 & sleep 0.8; }; }

# The transitions where something crosses the screen. awww's own 'random' is no
# good here: it can land on 'simple' or 'fade', and a dissolve is the one thing
# this is meant to stop doing. 'center' and 'any' are left out for a different
# reason — both are 'grow' with the centre pinned or randomised, and the centre
# gets randomised below anyway.
AWWW_ANIMS=(left right top bottom wipe wave grow outer)
ANIM_SECS="${WALL_ANIM_SECS:-1.1}"

# Rolls one transition and leaves its flags in AWWW_ANIM. Whatever the effect
# takes a parameter for gets a random one too — an angle for the ones that
# sweep, a centre for the ones that are circles — so the same effect coming up
# twice still does not arrive the same way.
#
# Rolled once per change rather than once per monitor: two screens moving to the
# same wallpaper should move together. WALL_ANIM=0 pins it back to the fixed
# circle from the centre this used to always do.
awww_anim() {
    AWWW_ANIM=(--transition-duration "$ANIM_SECS" --transition-fps 90)
    if [[ "${WALL_ANIM:-1}" != "1" ]]; then
        AWWW_ANIM+=(--transition-type grow --transition-pos center)
        return
    fi
    local t="${AWWW_ANIMS[RANDOM % ${#AWWW_ANIMS[@]}]}"
    AWWW_ANIM+=(--transition-type "$t")
    case "$t" in
        wipe)
            AWWW_ANIM+=(--transition-angle "$((RANDOM % 360))") ;;
        wave)
            AWWW_ANIM+=(--transition-angle "$((RANDOM % 360))"
                        --transition-wave "$((12 + RANDOM % 24)),$((12 + RANDOM % 24))") ;;
        grow|outer)
            # Floats are read as percentages, and 15–85 keeps the centre inside
            # the middle of the screen: a circle centred on the edge spends most
            # of its run off-screen and just reads as another wipe.
            AWWW_ANIM+=(--transition-pos "0.$((15 + RANDOM % 71)),0.$((15 + RANDOM % 71))") ;;
    esac
}

img_apply() {
    local mon path outs=()
    awww_anim
    while read -r mon; do
        [[ -z "$mon" ]] && continue
        path="$(st ".monitors[\"$mon\"] | select(.type==\"image\") | .path")"
        [[ -z "$path" || "$path" == "null" ]] && continue
        [[ -f "$path" ]] || continue
        awww_ready
        awww img "$path" -o "$mon" "${AWWW_ANIM[@]}" >/dev/null 2>&1
        outs+=("$mon")
    done < <(monitors)
    [[ ${#outs[@]} -gt 0 ]]
}

# linux-wallpaperengine's --screenshot is global: with a scene on more than one
# monitor it writes the whole layout in one image (4480x1440 here). Crop the
# main monitor's rectangle out of it so the palette, hyprlock and the launcher
# only ever see that screen.
crop_to_main() {
    local shot="$1" main geom w h
    main="$(main_monitor)"
    command -v magick >/dev/null || return 0
    [[ -s "$shot" ]] || return 1

    geom="$(magick identify -format '%w %h' "$shot" 2>/dev/null)"
    read -r w h <<< "$(hyprctl monitors -j | jq -r --arg m "$main" '.[] | select(.name==$m) | "\(.width) \(.height)"')"
    [[ -z "$w" ]] && return 0
    [[ "$geom" == "$w $h" ]] && return 0     # already just the one monitor

    log "cropping the ${geom// /x} capture down to $main (${w}x${h})"
    magick "$shot" -crop "${w}x${h}+0+0" +repage "$shot" 2>/dev/null || true
}

# Park the scene's still frame on the awww layer, underneath Wallpaper Engine.
# WE draws on top, so nothing changes while it runs — but the moment it stops
# (game mode, or the gap while a scene is being swapped) that frame is what
# shows, instead of a black flash. It also gives awww something to cross-fade
# out of when the next wallpaper lands.
#
# we_still_to_awww <still> [animate]
#   animate=0 (the default) drops the frame in with no transition: it is hidden
#     behind WE, so animating it would be wasted GPU.
#   animate=1 runs one of the transitions above instead and blocks until it has
#     finished. That is the hand-off apply() uses for a scene that is already
#     cached — the still moves in on the awww layer, and only once it has landed
#     does Wallpaper Engine start and draw over the top of it.
we_still_to_awww() {
    local still="${1:-$WE_SHOT}" animate="${2:-0}" outs
    [[ -s "$still" ]] || return 0
    awww_ready
    # Only the screens actually running a scene. Without -o this lands on every
    # output, and on a mixed setup it would paint over the picture img_apply
    # just put on the other monitor — which nobody noticed while the transition
    # was 'none' and the frame was hidden behind WE anyway.
    outs="$(st '[.monitors | to_entries[] | select(.value.type=="we") | .key] | join(",")')"
    local -a args=(img "$still")
    [[ -n "$outs" && "$outs" != "null" ]] && args+=(-o "$outs")
    if [[ "$animate" == "1" ]]; then
        awww_anim
        args+=("${AWWW_ANIM[@]}")
    else
        args+=(--transition-type none)
    fi
    awww "${args[@]}" >/dev/null 2>&1 || true
    # awww hands the animation to the daemon and returns immediately, so waiting
    # it out is on us. The extra beat is for the last frame to be on screen
    # before something else starts drawing over it.
    [[ "$animate" == "1" ]] &&
        sleep "$(awk -v s="$ANIM_SECS" 'BEGIN { print s + 0.2 }')"
    return 0
}

# ──────────────────────────────── theming ───────────────────────────────────
# theme_from <image> [source-colour] [mode] [type]
# With a source colour it skips matugen's image analysis and rebuilds the scheme
# straight from that colour; mode and type come from the M entry, so editing one
# by hand is enough to pin a scene to a colour you picked or to light mode.
theme_from() {
    local src="$1" color="${2:-}" mode="${3:-}" type="${4:-}"
    [[ -f "$src" ]] || { log "no image to pull colours from"; return 1; }

    # SKIP_THEME=1 restarts the wallpaper without rebuilding the palette. Used
    # by gamemode.sh, which only wants to change the Wallpaper Engine frame
    # rate: running matugen would rewrite conf/colors.lua, and the config reload
    # that follows wipes every runtime setting game mode just applied.
    if [[ "${SKIP_THEME:-0}" == "1" ]]; then
        log "SKIP_THEME=1: leaving the palette alone"
        return 0
    fi

    # current.png is the reference for hyprlock and the shell, and it has to be
    # an actual PNG: hyprlock picks its decoder from the extension, so a JPEG
    # sitting under a .png name goes to libpng and comes back as a black lock
    # screen. The cached stills are JPEG and so are most of the wallpapers in
    # Pictures, so this is a re-encode rather than a copy — 0.26 s at
    # compression level 1, which is the point of pinning the level.
    local cur_tmp="$CACHE_DIR/current.tmp.png"
    if command -v magick >/dev/null &&
       magick "$src" -define png:compression-level=1 "$cur_tmp" 2>/dev/null; then
        mv -f "$cur_tmp" "$CURRENT"
    elif [[ "$src" != "$CURRENT" ]]; then
        cp -f "$src" "$CURRENT" 2>/dev/null || ln -sf "$src" "$CURRENT"
    fi

    # Side image for the rofi launcher. The theme scales this to the launcher
    # window, so the canvas carries the launcher's own 2:1 ratio and the picture
    # is pinned to the left edge — the left half is the only part that is not
    # covered by an opaque widget. Both axes then scale by the same factor
    # whatever size the window ends up at, so the picture is framed identically
    # on every monitor instead of being drawn proportionally to the screen's
    # resolution.
    #
    # It runs 1100 wide rather than exactly half of 2000 so it overshoots the
    # results panel and slides under it. The window's 2px border means the
    # background is scaled into 996px while the left column is still 500px
    # wide, and an image that stopped dead at the halfway mark left a sliver of
    # bare canvas showing down the right-hand side of the picture.
    # (-gravity NorthWest matters: the crop's own gravity would otherwise still
    # be active and drop the image in the middle of the canvas.)
    if command -v magick >/dev/null; then
        magick -size 2000x1000 xc:'#000000' \
            \( "$CURRENT" -resize 1100x1000^ -gravity center -extent 1100x1000 \) \
            -gravity NorthWest -geometry +0+0 -composite \
            "$CACHE_DIR/launcher.png" 2>/dev/null || true
    fi

    # Rendering the ten templates is cheap; the post_hooks behind them are not —
    # plasma-apply-colorscheme, the VS Code settings merge and the Papirus icon
    # rebuild add up to ~2.6 s. When the scene resolves to the colour the desktop
    # is already wearing, every one of those outputs is already on disk and
    # correct, so none of it has to run. This is what makes re-applying a
    # wallpaper, or restoring one at login, effectively free.
    # `theme` forces a rebuild, for when a template itself has changed.
    # It has to be the same picture and not just the same colour: colors.conf
    # also carries the path hyprlock locks onto, so two different wallpapers
    # that happen to resolve to one colour must still go through matugen.
    if [[ -n "$color" && "${FORCE_THEME:-0}" != "1" &&
          "$color" == "$(st '.source // empty')" &&
          "$src"   == "$(st '.theme  // empty')" ]] &&
       [[ -s "$HOME/.config/quickshell/colors.json" &&
          -s "$HOME/.config/hypr/conf/colors.lua" ]]; then
        log "palette is already $color: nothing to rebuild"
        st_set_str '.theme' "$src"
        return 0
    fi

    local extra=()
    [[ -n "$mode" ]] && extra+=(-m "$mode")
    [[ -n "$type" ]] && extra+=(-t "$type")

    if [[ -n "$color" ]]; then
        # `matugen color` has no image to report, so {{image}} would render as
        # Null and hyprlock's background would end up with `path = Null` — a
        # black lock screen. Hand it the picture the colour came from.
        log "building the palette from the cached colour $color"
        matugen "${extra[@]}" --import-json-string "$(jq -n --arg i "$CURRENT" '{image:$i}')" \
            color hex "$color" >/dev/null 2>&1 || {
            log "matugen failed"; return 1; }
    else
        log "generating the palette with matugen"
        matugen "${extra[@]}" image "$CURRENT" --prefer saturation >/dev/null 2>&1 || {
            log "matugen failed"; return 1; }
    fi

    st_set_str '.theme' "$src"
    # Empty when the colours came out of an image directly (a static wallpaper):
    # that clears the marker, so the next theme always rebuilds.
    st_set_str '.source' "$color"

    # Hot reloads, no process killing.
    hyprctl reload >/dev/null 2>&1 || true          # Hyprland re-reads conf/colors.lua
    pkill -USR2 -x waybar 2>/dev/null || true       # waybar reloads its style (fallback)
    pkill -USR1 -x kitty  2>/dev/null || true       # kitty reloads its colours
    # Quickshell watches colors.json and recolours itself.
}

# Theme from a scene's cached still, using its cached palette if there is one.
theme_cached() {
    local id="$1" img="$2" f color="" mode="" type=""
    # Game mode restores the wallpaper with SKIP_THEME=1 and wants nothing else
    # touched — not even the one matugen call that would fill in a missing M.
    [[ "${SKIP_THEME:-0}" == "1" ]] && return 0
    if f="$(cache_find "$M_DIR" "$id" 'json')"; then
        color="$(jq -r '.source // empty' "$f" 2>/dev/null)"
        mode="$(jq -r  '.mode   // empty' "$f" 2>/dev/null)"
        type="$(jq -r  '.type   // empty' "$f" 2>/dev/null)"
    fi
    # A still in W with nothing beside it in M: either the capture we just took,
    # or one you put there yourself because this scene never screenshots well.
    # Either way the colours get read off it once and filed, and from then on
    # this scene costs a template render and nothing else.
    if [[ -z "$color" ]]; then
        log "no palette cached for $id: reading it off the still"
        color="$(cache_save_palette "$id" "$img" || true)"
    fi
    theme_from "$img" "$color" "$mode" "$type"
}

# ─────────────────────────────── actions ────────────────────────────────────
apply() {
    we_stop
    local need_we=0
    [[ "$(st '[.monitors[] | select(.type=="we")] | length')" != "0" ]] && need_we=1

    img_apply || true

    if [[ $need_we -eq 1 ]]; then
        local id still
        id="$(theme_we_id || true)"

        # Already have a still for this scene? Then nothing gets captured:
        # Wallpaper Engine starts without --screenshot and the palette comes out
        # of M. This is the fast path, and it is the one that runs almost always.
        if [[ -n "$id" && "${RECAPTURE:-0}" != "1" ]]; then
            still="$(cache_find "$W_DIR" "$id" || true)"
            if [[ -n "$still" ]]; then
                log "cached still for $id: skipping the capture"
                # A cached scene is the one case where there is a picture of it
                # on disk before it runs, so the change can be animated like any
                # other wallpaper: awww brings the still in, Wallpaper Engine
                # starts the moment the transition lands, and the recolour comes
                # after — matugen and its post hooks are ~2.5 s, and waiting on
                # them is 2.5 s of nothing happening on screen. It was tried the
                # other way round, palette first, and the wait is what you notice
                # rather than the colours arriving in the right order.
                #
                # we_stop at the top of apply() already took the old scene down,
                # so what the transition moves away from is the still parked
                # underneath it. Nothing to animate on the uncached path — the
                # frame does not exist until the capture has been taken — so that
                # one is untouched. WALL_WE_ANIM=0 goes back to starting WE
                # first, with no transition at all.
                if [[ "${WALL_WE_ANIM:-1}" == "1" ]]; then
                    we_still_to_awww "$still" 1
                    we_start 0
                else
                    we_start 0
                    we_still_to_awww "$still"
                fi
                theme_cached "$id" "$still" && return 0
                # The theme failed, so fall through and take a fresh capture —
                # but not on top of the scene that is already up, or we_start
                # would put a second copy of Wallpaper Engine on the screen.
                we_stop
            fi
        fi

        we_start
        if [[ -s "$WE_SHOT" ]]; then
            crop_to_main "$WE_SHOT"
            we_still_to_awww "$WE_SHOT"
            if [[ -n "$id" ]]; then
                still="$(cache_save_shot "$id" "$WE_SHOT" || true)"
                theme_cached "$id" "${still:-$WE_SHOT}" && return 0
            else
                theme_from "$WE_SHOT" && return 0
            fi
        fi
    fi

    # No wallpaper engine: take the palette from the main monitor's image
    local main pick
    main="$(main_monitor)"
    pick="$(st ".monitors[\"$main\"] | select(.type==\"image\") | .path")"
    [[ -z "$pick" || "$pick" == "null" ]] &&
        pick="$(st '[.monitors[] | select(.type=="image") | .path] | first // empty')"
    [[ -n "$pick" && -f "$pick" ]] && theme_from "$pick"
}

set_image() {
    local path="$1" mon="${2:-}"
    [[ -f "$path" ]] || { log "no such file: $path"; exit 1; }
    path="$(realpath "$path")"
    if [[ -n "$mon" ]]; then
        st_set ".monitors[\"$mon\"] = {\"type\":\"image\",\"path\":\"$path\"}"
    else
        st_set '.monitors = {}'
        while read -r m; do
            [[ -z "$m" ]] && continue
            st_set ".monitors[\"$m\"] = {\"type\":\"image\",\"path\":\"$path\"}"
        done < <(monitors)
    fi
    apply
    notify "Wallpaper" "$(basename "$path")"
}

set_we() {
    local id="$1" mon="${2:-}"
    [[ -d "$WS_DIR/$id" ]] || { log "id $id is not in the workshop"; exit 1; }
    if [[ -n "$mon" ]]; then
        st_set ".monitors[\"$mon\"] = {\"type\":\"we\",\"id\":\"$id\"}"
    else
        st_set '.monitors = {}'
        while read -r m; do
            [[ -z "$m" ]] && continue
            st_set ".monitors[\"$m\"] = {\"type\":\"we\",\"id\":\"$id\"}"
        done < <(monitors)
    fi
    apply
    notify "Wallpaper Engine" "$(we_title "$id")"
}

random_wall() {
    local mon="${1:-}" pick kind
    # 50/50 between an image and a wallpaper engine scene (when both exist)
    local -a imgs wes
    mapfile -t imgs < <(find "$IMG_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf)
    mapfile -t wes  < <(find "$WS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | shuf)

    if [[ ${#imgs[@]} -gt 0 && ${#wes[@]} -gt 0 ]]; then
        (( RANDOM % 2 == 0 )) && kind=img || kind=we
    elif [[ ${#imgs[@]} -gt 0 ]]; then kind=img
    elif [[ ${#wes[@]} -gt 0 ]]; then kind=we
    else log "no wallpapers found"; exit 1; fi

    if [[ $kind == img ]]; then
        pick="${imgs[0]}"; set_image "$pick" "$mon"
    else
        pick="${wes[0]}";  set_we "$pick" "$mon"
    fi
}

# Throw away what we have for a scene and take a fresh capture. For the ones
# that never screenshot well: some scenes fade in, some are black on the frame
# Wallpaper Engine happens to dump, some just look better a few seconds later.
recapture() {
    local id="${1:-}" cur
    cur="$(theme_we_id || true)"
    [[ -z "$id" ]] && id="$cur"
    [[ -n "$id" ]] || { log "no wallpaper engine scene is up, and none was named"; exit 1; }
    [[ -d "$WS_DIR/$id" ]] || { log "id $id is not in the workshop"; exit 1; }

    cache_drop "$id"
    notify "Wallpaper" "Recapturing $(we_title "$id")…"
    # Naming a scene that isn't up means "put it up and capture it".
    if [[ "$id" == "$cur" ]]; then RECAPTURE=1 apply
    else                           RECAPTURE=1 set_we "$id"; fi
}

cache_cmd() {
    local id
    case "${1:-ls}" in
        ls)
            while read -r d; do
                id="$(basename "$d")"
                printf '%s%s  %-12s %s\n' \
                    "$(cache_find "$W_DIR" "$id"        >/dev/null 2>&1 && echo W || echo ·)" \
                    "$(cache_find "$M_DIR" "$id" 'json' >/dev/null 2>&1 && echo M || echo ·)" \
                    "$id" "$(we_title "$id")"
            done < <(find "$WS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort) ;;
        path)
            [[ -n "${2:-}" ]] || { log "usage: cache path <id>"; exit 1; }
            printf '%s.jpg\n'  "$W_DIR/$(cache_name "$2")"
            printf '%s.json\n' "$M_DIR/$(cache_name "$2")" ;;
        set)
            # File a picture of your own as a scene's still, for the scenes
            # Wallpaper Engine will not screenshot properly. Saves you having to
            # match the naming by hand, and builds the palette right away.
            [[ -n "${2:-}" && -n "${3:-}" ]] || { log "usage: cache set <id> <image>"; exit 1; }
            [[ -f "$3" ]] || { log "no such file: $3"; exit 1; }
            cache_drop "$2"
            local still
            still="$(cache_save_shot "$2" "$3")" || exit 1
            cache_save_palette "$2" "$still" >/dev/null || exit 1
            log "$2 is now using $(basename "$3")" ;;
        rm)
            [[ -n "${2:-}" ]] || { log "usage: cache rm <id>"; exit 1; }
            cache_drop "$2"; log "cache cleared for $2" ;;
        *)  log "usage: cache [ls] | cache path <id> | cache set <id> <image> | cache rm <id>"
            exit 1 ;;
    esac
}

off() {
    we_stop
    awww_ready && awww clear 000000 >/dev/null 2>&1
    st_set '.monitors = {}'
    notify "Wallpaper" "turned off"
}

# ── refresh: put the wallpaper back after the outputs changed ────────────────
# linux-wallpaperengine asks the compositor for one layer surface per monitor
# and never asks again. When an output goes away — DP-1 dropping its link for a
# second, a head appearing or leaving for the remote session — Hyprland destroys
# those surfaces ("Compositor closed our LS, freeing data..." in we.log) and the
# process keeps running with nothing to draw on. What is left on screen is the
# still frame awww holds underneath, which is exactly what "the wallpaper paused
# by itself" looks like. Restarting it is the only way back.
#
# flock collapses a burst of events into one restart, and the sleep lets the
# outputs settle first so the new process is started against the final layout.
# SKIP_THEME=1 because the scene did not change: no matugen, no config reload.
refresh() {
    exec 9>"$STATE_DIR/refresh.lock"
    flock -n 9 || { log "a refresh is already pending"; return 0; }
    sleep "${WALL_REFRESH_DELAY:-2}"
    [[ "$(st '[.monitors[] | select(.type=="we")] | length')" == "0" ]] && return 0
    log "outputs changed: restarting wallpaper engine"
    SKIP_THEME=1 apply
}

# Everything the Quickshell picker needs, in one line of JSON: the catalogue,
# the monitors it can target, and what is currently set on each of them.
list_json() {
    local items
    items=$({
        find "$IMG_DIR" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) |
            sort | while read -r p; do
                printf 'image\t%s\t%s\t%s\t0\t%s\n' \
                    "$p" "$(basename "$p")" "$p" "$(stat -c %Y "$p" 2>/dev/null || echo 0)"
            done
        find "$WS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
            sort | while read -r d; do
                local id title prev cached
                id="$(basename "$d")"
                title="$(we_title "$id")"
                # Our own capture wins over the frame Wallpaper Engine ships:
                # those are 192px GIFs and 1024px squares, on a 560px card.
                cached="$(cache_find "$W_DIR" "$id" || true)"
                prev="${cached:-$(we_preview "$d")}"
                # A scene with neither would be a blank card: skip it. A scene
                # with only a cached still is fine — that is the case where you
                # dropped a picture into W for something WE never previewed.
                [[ -n "$prev" ]] || continue
                printf 'we\t%s\t%s\t%s\t%s\t%s\n' "$id" "$title" "$prev" \
                    "$([[ -n "$cached" ]] && echo 1 || echo 0)" \
                    "$(stat -c %Y "$prev" 2>/dev/null || echo 0)"
            done
    } | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") |
                     { kind: .[0], value: .[1], title: .[2], preview: .[3],
                       cached: (.[4] == "1"), stamp: (.[5] // "0") })')

    jq -n -c --argjson items "$items" \
             --argjson state "$(cat "$STATE")" \
             --argjson monitors "$(hyprctl monitors -j | jq -c '[.[].name]')" \
        '{ items: $items, monitors: $monitors, current: $state.monitors }'
}

usage() {
    cat <<EOF
Usage: wallpaper.sh <action> [args]

  image <path> [monitor]   set an image (on one monitor or all of them)
  we <id>      [monitor]   set a Wallpaper Engine scene
  random       [monitor]   pick one at random
  restore                  re-apply whatever you had (used by autostart)
  refresh                  put it back after a monitor was plugged/unplugged
                           (autostart hooks this to monitor.added/removed)
  theme                    regenerate just the colour palette
  recapture    [id]        throw away the cached still + palette and retake them
                           (defaults to the scene the theme comes from)
  cache ls                 every scene, and whether it has a still (W) / palette (M)
  cache path <id>          where to put a still and a palette for that scene
  cache set <id> <image>   use a picture of your own as that scene's still
  cache rm <id>            forget a scene's still and palette
  off                      remove the wallpaper
  list                     list what's available (for the rofi picker)
  list-json                the same, as JSON (for the Quickshell picker)
  current                  what is on each monitor right now, as one-line JSON
  static                   stop the animation, keep the still frame
  state                    print the current state

Wallpaper Engine scenes are cached under $CACHE_ROOT:
  W/  the still, "<id> — <title>.jpg". Drop your own in as "<id>.jpg" and it
      is used as-is, both for the palette and as the picker's thumbnail.
  M/  the palette, "<id> — <title>.json". Built from the still the first time
      the scene comes up. Edit .source to pin a scene to a colour you picked.
With both present a scene costs no screenshot and no image analysis.

Variables: WE_FPS (default 60), WE_VOLUME (0 = muted),
           WALL_CACHE_ROOT, WALL_SHOT_QUALITY (default 95), RECAPTURE=1
           WALL_ANIM=0        always the old circle-from-the-centre transition
                              instead of a random one
           WALL_ANIM_SECS     how long a transition takes (default 1.1)
           WALL_WE_ANIM=0     start a cached scene straight away, without
                              animating its still in first
EOF
}

case "${1:-}" in
    image)   shift; set_image "$@" ;;
    we)      shift; set_we "$@" ;;
    random)  shift; random_wall "${1:-}" ;;
    restore)
        if [[ "$(st '.monitors | length')" == "0" ]]; then
            log "no saved state: falling back to the current image if there is one"
            [[ -f "$CURRENT" ]] && { awww_ready; awww img "$CURRENT" >/dev/null 2>&1; }
        else
            apply
        fi ;;
    static)
        # Stop the animated wallpaper and leave the still frame in its place,
        # without touching the saved state, so `restore` brings everything back.
        # Game mode uses this: an animated wallpaper behind a fullscreen game
        # burns GPU on something direct scanout means you cannot even see.
        we_stop
        [[ -f "$CURRENT" ]] && { awww_ready; awww img "$CURRENT" >/dev/null 2>&1; }
        log "wallpaper engine stopped, still frame left up" ;;
    theme)
        # Go back through the cache when a scene is up, so a re-theme lands on
        # exactly the colours the scene is filed under.
        theme_id="$(theme_we_id || true)"
        theme_still=""
        [[ -n "$theme_id" ]] && theme_still="$(cache_find "$W_DIR" "$theme_id" || true)"
        export FORCE_THEME=1
        if [[ -n "$theme_still" ]]; then
            theme_cached "$theme_id" "$theme_still"
        else
            theme_from "$(st '.theme // empty')" || theme_from "$CURRENT"
        fi ;;
    refresh) refresh ;;
    recapture) shift; recapture "${1:-}" ;;
    cache)   shift; cache_cmd "$@" ;;
    off)     off ;;
    state)   jq . "$STATE" ;;
    # Just what is up right now, on one line. The picker re-reads this every
    # time it opens: the catalogue is expensive and can be cached, but which
    # wallpaper is current changes underneath it (from here, from rofi, from
    # `random`) and must not be.
    current) jq -c '.monitors' "$STATE" ;;
    list-json) list_json ;;
    list)
        find "$IMG_DIR" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf 'image\t%p\n'
        find "$WS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | \
            while read -r id; do printf 'we\t%s\t%s\n' "$id" "$(we_title "$id")"; done ;;
    ""|-h|--help) usage ;;
    *)       usage; exit 1 ;;
esac
