#!/usr/bin/env bash

set -euo pipefail

WALL_DIR="$HOME/Pictures/wallpaper"
CACHE_DIR="$HOME/.cache/wall-thumbs"
TARGET="$HOME/.config/hypr/wallpaper.png"
ROFI_THEME="$HOME/.config/rofi/wallpaper_switcher.rasi"
QS_CONFIG_PATH="$HOME/.config/quickshell/dynamic_island"

TRANSITION_TYPE="wipe"
TRANSITION_ANGLE="225"
TRANSITION_STEP="90"
TRANSITION_FPS="60"
TRANSITION_DURATION="0.8"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$1" >&2
        exit 1
    fi
}

ensure_daemon() {
    if ! awww query >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
        sleep 1
    fi
}

reload_waybar_if_running() {
    if pgrep -x waybar >/dev/null 2>&1; then
        pkill -x waybar || true
        waybar >/dev/null 2>&1 &
    fi
}

require_command awww
require_command awww-daemon
require_command magick
require_command rofi
require_command wal

mkdir -p "$CACHE_DIR"

shopt -s nullglob
wallpapers=(
    "$WALL_DIR"/*.jpg
    "$WALL_DIR"/*.jpeg
    "$WALL_DIR"/*.png
    "$WALL_DIR"/*.webp
    "$WALL_DIR"/*.gif
    "$WALL_DIR"/*.bmp
    "$WALL_DIR"/*.JPG
    "$WALL_DIR"/*.JPEG
    "$WALL_DIR"/*.PNG
    "$WALL_DIR"/*.WEBP
    "$WALL_DIR"/*.GIF
    "$WALL_DIR"/*.BMP
)
shopt -u nullglob

if [[ ${#wallpapers[@]} -eq 0 ]]; then
    printf 'No wallpapers found in %s\n' "$WALL_DIR" >&2
    exit 1
fi

for img in "${wallpapers[@]}"; do
    name=$(basename "$img")
    thumb="$CACHE_DIR/$name"

    if [[ ! -f "$thumb" || "$img" -nt "$thumb" ]]; then
        magick "$img[0]" -auto-orient -resize 400x400^ -gravity center -extent 400x400 "$thumb"
    fi
done

choice=$(
    for img in "${wallpapers[@]}"; do
        name=$(basename "$img")
        printf '%s\0icon\x1f%s\n' "$name" "$CACHE_DIR/$name"
    done | rofi -dmenu -theme "$ROFI_THEME" -p "Wallpaper"
)

[[ -n "$choice" ]] || exit 0

SELECTED_IMG="$WALL_DIR/$choice"
if [[ ! -f "$SELECTED_IMG" ]]; then
    printf 'Selected wallpaper not found: %s\n' "$SELECTED_IMG" >&2
    exit 1
fi

ensure_daemon
cp -f "$SELECTED_IMG" "$TARGET"
quickshell ipc -p "$QS_CONFIG_PATH" call overview refreshWallpaperCache >/dev/null 2>&1 || true

wal -q -i "$SELECTED_IMG" -n >/dev/null 2>&1 &
wal_pid=$!

awww img "$SELECTED_IMG" \
    --resize crop \
    --transition-type "$TRANSITION_TYPE" \
    --transition-angle "$TRANSITION_ANGLE" \
    --transition-step "$TRANSITION_STEP" \
    --transition-fps "$TRANSITION_FPS" \
    --transition-duration "$TRANSITION_DURATION"

sleep "$TRANSITION_DURATION"
wait "$wal_pid"
reload_waybar_if_running
