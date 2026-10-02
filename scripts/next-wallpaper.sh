#!/bin/bash

DIR="$HOME/Pictures/Wallpapers"
CACHE_FILE="$HOME/.cache/wallpaper_index"

shopt -s nullglob nocaseglob

files=("$DIR"/*.{jpg,png,jpeg,bmp,gif})

n=${#files[@]}

if [ "$n" -eq 0 ]; then
    echo "No files found."
    exit 1
fi

# Read previous index or default to 0
current_index=0
if [ -f "$CACHE_FILE" ]; then
    current_index=$(<"$CACHE_FILE")
    # Validate index is an integer
    if ! [[ "$current_index" =~ ^[0-9]+$ ]]; then
        current_index=0
    fi
fi

# Calculate next index (loops back to 0 at the end)
next_index=$(( (current_index + 1) % n ))

# Save new index
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$next_index" > "$CACHE_FILE"

next_file="${files[$next_index]}"

awww img --transition-type none "$next_file"
echo "Selected next file ($((next_index + 1))/$n): $next_file"