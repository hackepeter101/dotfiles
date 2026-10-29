#!/usr/bin/env bash

# Check that this machine matches the repository: every declared package is
# installed, fonts and cursor exist, every config file is linked into $HOME,
# no links dangle, and the default applications are set.
#
# Run it after changing configs or on a fresh install. It only reads; the
# fix for a failure is usually running scripts/install.sh again.

set -uo pipefail

REPOSITORY_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_DIR

# Font families the configs name. Keep in sync when changing a font.
readonly FONTS=("ComicShannsMono Nerd Font")
readonly WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

failures=0
warnings=0

ok()   { printf '  \e[32m✓\e[0m %s\n' "$*"; }
fail() { printf '  \e[31m✗\e[0m %s\n' "$*"; ((failures++)); }
warn() { printf '  \e[33m!\e[0m %s\n' "$*"; ((warnings++)); }

read_list() {
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$REPOSITORY_DIR/setup/$1"
}

check_packages() {
    local list="$1" package missing=()

    while read -r package; do
        pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
    done < <(read_list "$list")

    if ((${#missing[@]})); then
        fail "$list: not installed: ${missing[*]}"
    else
        ok "$list: all installed"
    fi
}

check_fonts() {
    local font
    for font in "${FONTS[@]}"; do
        if fc-list : family | tr ',' '\n' | grep -xF "$font" >/dev/null; then
            ok "font: $font"
        else
            fail "font missing: $font"
        fi
    done
}

check_cursor() {
    local cursor
    cursor="$(sed -n 's/.*"XCURSOR_THEME", "\([^"]*\)".*/\1/p' \
        "$REPOSITORY_DIR/hyprland/.config/hypr/config/environment.lua")"

    if [[ -d "/usr/share/icons/$cursor" || -d "$HOME/.local/share/icons/$cursor" ]]; then
        ok "cursor: $cursor"
    else
        fail "cursor theme missing: $cursor"
    fi
}

check_links() {
    local package source destination unlinked

    while read -r package; do
        unlinked=()
        while IFS= read -r -d '' source; do
            destination="$HOME/${source#"$REPOSITORY_DIR/$package/"}"
            [[ "$(readlink -f -- "$destination")" == "$source" ]] || unlinked+=("${destination/#$HOME/\~}")
        done < <(find "$REPOSITORY_DIR/$package" -type f -print0)

        if ((${#unlinked[@]})); then
            fail "$package: not linked from repo: ${unlinked[*]}"
        else
            ok "$package: linked"
        fi
    done < <(read_list stow-packages.txt)
}

check_dangling() {
    local link dangling=()

    # Only links into this repository are ours to report.
    while IFS= read -r -d '' link; do
        [[ "$(readlink -- "$link")" == *"$(basename -- "$REPOSITORY_DIR")/"* ]] && dangling+=("${link/#$HOME/\~}")
    done < <(find "$HOME/.config" -maxdepth 4 -xtype l -print0 2>/dev/null)

    if ((${#dangling[@]})); then
        fail "dangling links into the repo: ${dangling[*]}"
    else
        ok "no dangling links"
    fi
}

check_default_apps() {
    local desktop_file mime_types mime current wrong=()

    while read -r desktop_file mime_types; do
        for mime in $mime_types; do
            current="$(xdg-mime query default "$mime" 2>/dev/null)"
            [[ "$current" == "$desktop_file" ]] || wrong+=("$mime=${current:-none}")
        done
        if [[ ! -e "/usr/share/applications/$desktop_file" &&
              ! -e "$HOME/.local/share/applications/$desktop_file" ]]; then
            fail "default app not installed: $desktop_file"
        fi
    done < <(read_list default-apps.txt)

    if ((${#wrong[@]})); then
        fail "default apps differ from setup/default-apps.txt: ${wrong[*]}"
    else
        ok "default apps set"
    fi
}

check_gsettings() {
    local schema key value current wrong=()

    while read -r schema key value; do
        current="$(gsettings get "$schema" "$key" 2>/dev/null)"
        [[ "$current" == "$value" ]] || wrong+=("$schema $key=${current:-unset}")
    done < <(read_list gsettings.txt)

    if ((${#wrong[@]})); then
        fail "gsettings differ from setup/gsettings.txt: ${wrong[*]}"
    else
        ok "gsettings applied"
    fi
}

check_wallpapers() {
    if compgen -G "$WALLPAPER_DIR/*.*" >/dev/null; then
        ok "wallpapers found in ${WALLPAPER_DIR/#$HOME/\~}"
    else
        warn "no wallpapers in ${WALLPAPER_DIR/#$HOME/\~}; random-wallpaper.sh will show nothing"
    fi
}

printf 'Packages\n';     check_packages packages-repo.txt; check_packages packages-aur.txt
printf 'Appearance\n';   check_fonts; check_cursor; check_gsettings; check_wallpapers
printf 'Links\n';        check_links; check_dangling
printf 'Default apps\n'; check_default_apps

printf '\n%d failure(s), %d warning(s)\n' "$failures" "$warnings"
((failures == 0))
