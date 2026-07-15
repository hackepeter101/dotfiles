#!/bin/bash

DIR="$HOME/Pictures/Wallpapers"
shopt -s nullglob

files=("$DIR"/*.jpg "$DIR"/*.png "$DIR"/*.jpeg "$DIR"/*.bmp "$DIR"/*.gif "$DIR"/*.JPG "$DIR"/*.PNG "$DIR"/*.JPEG "$DIR"/*.BMP "$DIR"/*.GIF)

n=${#files[@]}

if [ "$n" -gt 0 ]; then
    random_index=$((RANDOM % n))
    random_file="${files[$random_index]}"
    awww img "$random_file"
    echo "Selected random file: $random_file"
else
    echo "No files found."
fi   