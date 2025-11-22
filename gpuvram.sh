#!/bin/bash

# waybar-dotfiles Copyright (C) 2025 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

kill $(pgrep -f "$(basename "$0")" | grep -v "^$$\$") 2>/dev/null || true

# Get VRAM usage in bytes from AMD GPU
vram_used_bytes=$(cat /sys/class/drm/card0/device/mem_info_vram_used 2>/dev/null)

# Check if we successfully read the value
if [ -z "$vram_used_bytes" ]; then
    echo "{\"text\": \"? GiB\"}"
    exit 1
fi

# Convert bytes to GiB (1 GiB = 1073741824 bytes)
vram_used_gib=$(awk "BEGIN {printf \"%.2f\", $vram_used_bytes/1073741824}")

echo "{\"text\": \"${vram_used_gib} GiB\"}"
