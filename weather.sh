#!/bin/bash

# weather.sh Copyright (C) 2025 kernaltrap8
# This program comes with ABSOLUTELY NO WARRANTY
# This is free software, and you are welcome to redistribute it
# under certain conditions

# bash setup
set -euo pipefail
LOG_PREFIX="/tmp/weather-sh"

# constants
CITY="Wichita"
LAT=37.6872
LON=-97.3301
LOG_FILE="${LOG_PREFIX}/weather.log"
ERROR_FILE="${LOG_PREFIX}/weather-error.log"
CACHE_FILE="${LOG_PREFIX}/weather-cache.txt"
CACHE_MAX_AGE=3600  # 1 hour in seconds

# bools
isLogEnabled=1

# logging setup
mkdir -p "${LOG_PREFIX}"

rotate_log() {
    local file="$1"
    local base="${file%%.*}"
    [[ -e "$file" ]] && mv "$file" "${base}-$(date '+%Y-%m-%d_%H%M%S').log"
    > "$file"
}

# Only rotate on first run of the day
if [[ ! -f "$LOG_FILE" ]] || [[ $(date -r "$LOG_FILE" +%Y%m%d) != $(date +%Y%m%d) ]]; then
    rotate_log "$LOG_FILE"
    rotate_log "$ERROR_FILE"
fi
exec 2>>"$ERROR_FILE"

function log_var() {
	if [[ $isLogEnabled -eq 0 ]]; then
		return
	fi
	local var_name=$1
	local var_value=${!var_name}
	printf '[%s] %s: %s\n' "$(date +"%Y/%m/%d-%H:%M:%S")" "$var_name" "$var_value" >> "$LOG_FILE"
}

function log_msg() {
	if [[ $isLogEnabled -eq 0 ]]; then
		return
	fi
	local var_value="$1"
	local caller="${FUNCNAME[1]}"
	printf '[%s] %s: %s\n' "$(date +"%Y/%m/%d-%H:%M:%S")" "$caller" "$var_value" >> "$LOG_FILE"
}

function check_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-v|--version)
				echo -e "weather.sh Copyright (C) 2025 kernaltrap8\nThis program is licensed under the BSD-3-Clause license.\nThe license document can be viewed here: https://opensource.org/license/bsd-3-clause"
				exit 0
				;;
			--disable-logging)
				isLogEnabled=0
				shift
				;;
			--force-refresh)
				rm -f "$CACHE_FILE"
				shift
				;;
			--)
				shift
				break
				;;
			-*)
				echo "Invalid option: $1" >&2
				exit 1
				;;
			*)
				break
				;;
		esac
	done
}

# Check if cache is valid
use_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt $CACHE_MAX_AGE ]]; then
            cat "$CACHE_FILE"
            log_msg "Using cached weather (age: ${cache_age}s)"
            return 0
        fi
    fi
    return 1
}

# main script functionality
function main() {
    # Try to use cache first
    if use_cache; then
        exit 0
    fi
    
    log_msg "Fetching fresh weather data"
    
    # Get observation station
    POINT_DATA=$(curl -s --max-time 10 "https://api.weather.gov/points/${LAT},${LON}" 2>/dev/null || echo '')
    log_var POINT_DATA
    STATIONS_URL=$(echo "$POINT_DATA" | jq -r '.properties.observationStations' 2>/dev/null || echo 'null')
    log_var STATIONS_URL
    
    # fallback if API fails
    if [ -z "$STATIONS_URL" ] || [ "$STATIONS_URL" = "null" ]; then
        echo "W: --"
        log_msg "ERROR: Failed to get station URL"
        exit 0
    fi
    
    # Get the nearest observation station
    STATION_ID=$(curl -s --max-time 10 "$STATIONS_URL" 2>/dev/null | jq -r '.observationStations[0]' 2>/dev/null || echo 'null')
    log_var STATION_ID
    
    if [ -z "$STATION_ID" ] || [ "$STATION_ID" = "null" ]; then
        echo "W: --"
        log_msg "ERROR: Failed to get station ID"
        exit 0
    fi
    
    # Fetch current observations
    OBSERVATIONS=$(curl -s --max-time 10 "${STATION_ID}/observations/latest" 2>/dev/null || echo '')
    log_var OBSERVATIONS
    
    # Extract data
    data=$(echo "$OBSERVATIONS" | jq '.properties' 2>/dev/null || echo 'null')
    log_var data
    
    cond=$(echo "$data" | jq -r '.textDescription // "Unknown"' 2>/dev/null || echo 'Unknown')
    temp_c=$(echo "$data" | jq -r '.temperature.value // "null"' 2>/dev/null || echo 'null')
    
    log_var cond
    log_var temp_c
        
    # Temperature is in Celsius, convert to Fahrenheit
    if [ "$temp_c" = "null" ] || [ -z "$temp_c" ]; then
        temp="--"
        unit="F"
    else
        temp=$(printf "%.0f" "$(echo "($temp_c * 9/5) + 32" | bc -l)")
        unit="F"
    fi
    log_var temp
    log_var unit
    
    # Determine if daytime (simple check: between 6 AM and 6 PM local time)
    current_hour=$(date +"%H")
    if [ "$current_hour" -ge 6 ] && [ "$current_hour" -lt 18 ]; then
        is_daytime="true"
    else
        is_daytime="false"
    fi
    log_var is_daytime
    
    # Emoji mapping
    emoji="❓"
    if [ "$is_daytime" = "false" ]; then
        # Night emojis
        case "$cond" in
            *Clear*|*Sunny*|*Fair*) emoji="🌙" ;;
            *Cloudy*|*Overcast*) emoji="🌃" ;;
            *"Partly Cloudy"*|*"Mostly Cloudy"*|*"Mostly Clear"*) emoji="🌃" ;;
            *Showers*|*Rain*|*Drizzle*) emoji="🌧️" ;;
            *Thunder*|*Storm*) emoji="⛈️" ;;
            *Snow*|*Flurries*) emoji="❄️" ;;
            *Fog*|*Mist*|*Haze*) emoji="🌫️" ;;
            *Windy*) emoji="🌬️" ;;
        esac
    else
        # Day emojis
        case "$cond" in
            *Clear*|*Sunny*|*Fair*) emoji="☀️" ;;
            *Cloudy*|*Overcast*) emoji="☁️" ;;
            *"Partly Cloudy"*|*"Mostly Cloudy"*) emoji="⛅" ;;
            *Showers*|*Rain*|*Drizzle*) emoji="🌧️" ;;
            *Thunder*|*Storm*) emoji="⛈️" ;;
            *Snow*|*Flurries*) emoji="❄️" ;;
            *Fog*|*Mist*|*Haze*) emoji="🌫️" ;;
            *Windy*) emoji="🌬️" ;;
        esac
    fi
    log_var emoji
    
    # Prefix + if non-negative number
    if [[ "$temp" != "--" && "$temp" -ge 0 ]]; then
        temp="+$temp"
    fi
    log_var temp
    
    # Output for i3status (plain text)
    output="$emoji $temp°$unit"
    echo "$output"
    
    # Cache the output
    echo "$output" > "$CACHE_FILE"
    
    log_var output
    
    # Check for empty/null values
    empty_vars=()
    vars_to_check=(
    	POINT_DATA
    	STATIONS_URL
    	STATION_ID
    	OBSERVATIONS
    	data
		cond
		temp_c
		temp
		unit
		current_hour
		is_daytime
		emoji
		output
    )
    for var in "${vars_to_check[@]}"; do
        [[ -z "${!var}" || "${!var}" = "null" ]] && empty_vars+=("$var")
    done
    if [ ${#empty_vars[@]} -gt 0 ]; then
        log_msg "WARNING: some values were empty! API is likely experiencing issues. Empty: ${empty_vars[*]}"
    fi
}

check_args "$@"
main
