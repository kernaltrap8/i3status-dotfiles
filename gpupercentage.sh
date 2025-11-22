#!/bin/bash

# i3status-dotfiles Copyright (C) 2025 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

kill $(pgrep -f "$(basename "$0")" | grep -v "^$$\$") 2>/dev/null || true

SCRIPTNAME="$(basename "$0")"
pgrep -f "$SCRIPTNAME" | grep -v "^$$\$" | xargs -r kill

output_file="$HOME/.config/i3status/gpu_percentage_status"

while true; do
	rocm-smi --showuse | awk '/GPU\[0\]/ {
    gsub(/%/, "", $NF);          # remove any existing % sign
    printf "G: %s%%\n", $NF      # print “G: <value>%”
	}' > "$output_file"
	sleep 1
done
