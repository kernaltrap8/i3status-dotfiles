#!/usr/bin/bash

# Path to your media script
media_status_file="$HOME/.config/i3status/media_status"

# Colors
COLOR_PLAYING="#00FF00"  # Green
COLOR_PAUSED="#888888"   # Grey
COLOR_FALLBACK="#888888" # Grey

# Function to get media status JSON
get_media_json() {
    if [[ -f "$media_status_file" ]]; then
        local content=$(cat "$media_status_file")
        local color="$COLOR_FALLBACK"
        
        if [[ "$content" =~ ^Pl: ]]; then
            color="$COLOR_PLAYING"
        elif [[ "$content" =~ ^Pz: ]]; then
            color="$COLOR_PAUSED"
        fi
        
        jq -nc --arg text "$content" --arg color "$color" \
            '{full_text: $text, color: $color, name: "media"}'
    else
        jq -nc --arg color "$COLOR_FALLBACK" \
            '{full_text: "S: No song", color: $color, name: "media"}'
    fi
}

i3status | while IFS= read -r line; do
    if [[ "$line" == \{* ]]; then
        # Pass through the version header
        echo "$line"
    elif [[ "$line" == "[" ]]; then
        # Pass through the opening bracket
        echo "$line"
    elif [[ "$line" == ,\[* ]]; then
        # This is a status update line starting with ,[
        # Remove the leading comma and bracket
        line="${line:2}"
        # Remove trailing ]
        line="${line%]}"
        
        # Get media status and prepend it
        media_json=$(get_media_json)
        echo ",[$media_json,$line]"
    else
        # Pass through anything else (like initial [])
        echo "$line"
    fi
done
