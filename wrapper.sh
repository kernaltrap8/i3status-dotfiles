#!/usr/bin/bash

# Path to your scripts
media_status_file="$HOME/.config/i3status/media_status"
weather_script="$HOME/.config/i3status/weather.sh"

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

# Function to get weather JSON
get_weather_json() {
    if [[ -x "$weather_script" ]]; then
        local weather=$("$weather_script" 2>/dev/null || echo "W: Error")
        jq -nc --arg text "$weather" \
            '{full_text: $text, color: "#FFFFFF", name: "weather"}'
    else
        jq -nc \
            '{full_text: "W: N/A", color: "#888888", name: "weather"}'
    fi
}

# Function to insert module after a specific module name
# Usage: insert_after "time" "$(get_weather_json)"
insert_after() {
    local target_name="$1"
    local new_module="$2"
    local modules="$3"
    
    # Parse the JSON array and insert after target
    echo "$modules" | jq --arg target "$target_name" --argjson new "$new_module" '
        . as $arr |
        ($arr | map(.name) | index($target)) as $idx |
        if $idx then
            $arr[0:$idx+1] + [$new] + $arr[$idx+1:]
        else
            $arr
        end
    '
}

# Function to insert module before a specific module name
# Usage: insert_before "memory" "$(get_weather_json)"
insert_before() {
    local target_name="$1"
    local new_module="$2"
    local modules="$3"
    
    # Parse the JSON array and insert before target
    echo "$modules" | jq --arg target "$target_name" --argjson new "$new_module" '
        . as $arr |
        ($arr | map(.name) | index($target)) as $idx |
        if $idx then
            $arr[0:$idx] + [$new] + $arr[$idx:]
        else
            $arr
        end
    '
}

# Function to prepend module (add at beginning)
prepend_module() {
    local new_module="$1"
    local modules="$2"
    
    echo "$modules" | jq --argjson new "$new_module" '[$new] + .'
}

# Function to append module (add at end)
append_module() {
    local new_module="$1"
    local modules="$2"
    
    echo "$modules" | jq --argjson new "$new_module" '. + [$new]'
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
        # Remove the leading comma and bracket, and trailing ]
        line="${line:2}"
        line="${line%]}"
        
        # Start with original modules
        modules="[$line]"
        
        # Add custom modules in desired positions
        # Add media at the beginning
        modules=$(prepend_module "$(get_media_json)" "$modules")
        
        # Add weather before time (between memory and time)
        modules=$(insert_before "time" "$(get_weather_json)" "$modules")
        
        # Output the modified array
        echo ",$modules"
    else
        # Pass through anything else
        echo "$line"
    fi
done
