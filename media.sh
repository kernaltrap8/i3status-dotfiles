#!/usr/bin/bash
player="strawberry"
output_file="$HOME/.config/i3status/media_status"
fallback_output="S: No song"
output_format="{{status}}|{{xesam:artist}} - {{xesam:title}}"

trap 'echo "$fallback_output" > "$output_file"' EXIT

# Initialize with fallback
echo "$fallback_output" > "$output_file"

# Wait for player to appear
while ! playerctl -l 2>/dev/null | grep -q "$player"; do
    sleep 0.1
done

# Event-driven loop
while IFS='|' read -r status song; do
    if [[ -z "$song" ]]; then
        output="$fallback_output"
    elif [[ "$status" == "Playing" ]]; then
        output="Pl: $song"
    elif [[ "$status" == "Paused" ]]; then
        output="Pz: $song"
    else
        output="$fallback_output"
    fi
    echo "$output" > "$output_file"
done < <(playerctl -p "$player" metadata --format "$output_format" --follow)
