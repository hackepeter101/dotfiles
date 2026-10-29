#!/usr/bin/env bash

# Install the user-level configuration from this repository.
#
# The repository is intentionally kept as a collection of GNU Stow packages:
# each package contains files relative to $HOME. Stow links those files into
# the user's home directory so changes remain version-controlled here and are
# immediately visible to the applications using them.
#
# By default, the required packages and the user configuration are installed.
# SDDM is installed only
# when --with-sddm is passed because it writes to system-owned directories.
# When this file is piped into Bash, the repository is located in an existing
# checkout or cloned to a persistent directory before GNU Stow runs.

set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/hackepeter101/dotfiles.git"
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/hackepeter101/dotfiles/master/scripts/install.sh"

# When invoked as `sudo ./install.sh --with-sddm`, sudo changes the process
# identity. Keep user configuration targeted at the user who invoked sudo,
# while the SDDM section below still writes to system paths as root.
if [[ "$EUID" -eq 0 ]]; then
    invoking_uid="${SUDO_UID:-}"
    if [[ -z "$invoking_uid" ]]; then
        invoking_user="${SUDO_USER:-$(logname 2>/dev/null || true)}"
        invoking_uid="$(id -u "$invoking_user" 2>/dev/null || true)"
    fi

    if [[ -n "$invoking_uid" && "$invoking_uid" != 0 ]]; then
        TARGET_USER="$(getent passwd "$invoking_uid" | cut -d: -f1)"
        TARGET_HOME="$(getent passwd "$invoking_uid" | cut -d: -f6)"
    else
        TARGET_USER="root"
        TARGET_HOME="$HOME"
    fi
else
    TARGET_USER="$(id -un)"
    TARGET_HOME="$HOME"
fi

if [[ -z "$TARGET_HOME" ]]; then
    printf '%s\n' 'Error: could not determine the target user home directory.' >&2
    printf '%s\n' 'Run the user install without sudo, or use sudo from a normal login shell.' >&2
    exit 1
fi

readonly TARGET_USER
readonly TARGET_HOME
readonly CONFIG_HOME="$TARGET_HOME/.config"
readonly DEFAULT_REPOSITORY_DIR="$TARGET_HOME/dotfiles"

DRY_RUN=false
WITH_SDDM=false
REPOSITORY_DIR=''

setup_repository() {
    local script_path="${BASH_SOURCE[0]:-}"

    # With `curl URL/install.sh | bash`, Bash reads the script from stdin and
    # there is no local directory containing the Stow packages. Prefer the
    # conventional ~/dotfiles checkout so an existing repository is reused.
    # A local copy lives in scripts/, one level below the repository root.
    if [[ -n "$script_path" && -f "$script_path" ]]; then
        REPOSITORY_DIR="$(cd -- "$(dirname -- "$script_path")/.." && pwd)"
        return
    fi

    local repository_dir="${DOTFILES_DIR:-$DEFAULT_REPOSITORY_DIR}"

    if [[ -d "$repository_dir/.git" ]]; then
        REPOSITORY_DIR="$(cd -- "$repository_dir" && pwd)"
        log "Using existing dotfiles checkout at $REPOSITORY_DIR"
        return
    fi

    if [[ -e "$repository_dir" ]]; then
        printf 'Error: %s exists but is not a Git checkout.\n' "$repository_dir" >&2
        printf '%s\n' 'Set DOTFILES_DIR to a different directory or remove the conflicting path.' >&2
        exit 1
    fi

    command -v git >/dev/null 2>&1 || {
        printf '%s\n' 'Error: git is required when install.sh is piped into Bash.' >&2
        exit 1
    }

    log "Cloning dotfiles into $repository_dir"
    mkdir -p "$(dirname -- "$repository_dir")"
    git clone --depth 1 "$REPOSITORY_URL" "$repository_dir"
    REPOSITORY_DIR="$(cd -- "$repository_dir" && pwd)"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Install the user configuration from this repository.

Options:
  --dry-run       Show actions without changing files
  --with-sddm     Also install the SDDM configuration (requires root)
  -h, --help      Show this help text

Remote usage:
    curl -fsSL $INSTALL_SCRIPT_URL | bash -s -- --dry-run

Piped installs use $DEFAULT_REPOSITORY_DIR, keeping the checkout beside the
configuration files just like a normal local install.
EOF
}

log() {
    printf '==> %s\n' "$*"
}

run() {
    # Printing commands makes --dry-run useful and keeps the installer easy
    # to audit when it is run on a machine with existing configuration.
    printf '    '
    printf '%q ' "$@"
    printf '\n'

    if ! "$DRY_RUN"; then
        "$@"
    fi
}

backup_config_path() {
    local destination="$1"
    local backup_path="${destination}.bak"

    # Never overwrite an older backup. A timestamp keeps repeated installs
    # reversible while retaining the simple .bak convention for the first
    # backup.
    if [[ -e "$backup_path" || -L "$backup_path" ]]; then
        backup_path="${destination}.bak.$(date +%Y%m%d-%H%M%S)"
    fi

    run mv -- "$destination" "$backup_path"
    log "Backed up $destination to $backup_path"
}

prepare_package_conflicts() {
    local package="$1"
    local source destination

    # Check every file of the package instead of whole directories: an
    # existing ~/.config/<app> may also hold personal files (bookmarks,
    # caches) that must stay in place next to the linked configuration.
    while IFS= read -r -d '' source; do
        destination="$TARGET_HOME/${source#"$REPOSITORY_DIR/$package/"}"

        # Already provided by this package, directly or through a linked
        # parent directory; Stow restows it safely.
        if [[ "$(readlink -f -- "$destination")" == "$source" ]]; then
            continue
        fi

        if [[ -e "$destination" || -L "$destination" ]]; then
            backup_config_path "$destination"
        fi
    done < <(find "$REPOSITORY_DIR/$package" -type f -print0)
}

read_list() {
    # The setup/*.txt lists hold one entry per line; comments and blank
    # lines are skipped so the lists can stay documented.
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$REPOSITORY_DIR/setup/$1"
}

install_packages() {
    # Everything the configuration starts or references is declared in
    # setup/packages-*.txt. --needed keeps repeated installs from
    # reinstalling packages that are already present.
    local packages aur_packages
    local privilege=()

    command -v pacman >/dev/null 2>&1 || {
        printf '%s\n' 'Warning: pacman not found; skipping package installation' >&2
        return
    }

    if [[ "$EUID" -ne 0 ]]; then
        privilege=(sudo)
    fi

    mapfile -t packages < <(read_list packages-repo.txt)
    run "${privilege[@]}" pacman -S --needed --noconfirm "${packages[@]}"

    # AUR helpers refuse to run as root, so they always run as the user
    # whose configuration is being installed.
    mapfile -t aur_packages < <(read_list packages-aur.txt)
    local aur_helper=''
    if command -v yay >/dev/null 2>&1; then
        aur_helper='yay'
    elif command -v paru >/dev/null 2>&1; then
        aur_helper='paru'
    fi

    if [[ -z "$aur_helper" ]]; then
        printf 'Warning: no AUR helper found; install manually: %s\n' "${aur_packages[*]}" >&2
    else
        as_target_user "$aur_helper" -S --needed "${aur_packages[@]}"
    fi
}

as_target_user() {
    # Run a command as the user whose configuration is installed, also when
    # the script itself runs as root through sudo.
    if [[ "$EUID" -eq 0 ]]; then
        run sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "$@"
    else
        run "$@"
    fi
}

set_default_apps() {
    # xdg-mime only rewrites the listed types, so personal associations in
    # ~/.config/mimeapps.list (mail client, URL handlers, ...) are kept.
    local desktop_file mime_types

    while read -r desktop_file mime_types; do
        # shellcheck disable=SC2086 # mime_types is a space-separated list
        as_target_user xdg-mime default "$desktop_file" $mime_types
    done < <(read_list default-apps.txt)
}

set_gsettings() {
    # Values may contain spaces (font names), so the key's remainder is
    # passed as one argument.
    local schema key value

    while read -r schema key value; do
        as_target_user gsettings set "$schema" "$key" "$value"
    done < <(read_list gsettings.txt)
}

install_user_configs() {
    local packages package
    mapfile -t packages < <(read_list stow-packages.txt)

    command -v stow >/dev/null 2>&1 || {
        printf '%s\n' 'Error: GNU Stow is required but was not found in PATH.' >&2
        exit 1
    }

    # Stow targets $HOME, so ~/.config must exist before any package is
    # restowed. This is harmless when the directory is already present.
    run mkdir -p "$CONFIG_HOME"

    for package in "${packages[@]}"; do
        if [[ ! -d "$REPOSITORY_DIR/$package/.config" ]]; then
            printf 'Warning: skipping %s; no .config directory found\n' "$package" >&2
            continue
        fi

        prepare_package_conflicts "$package"
        if "$DRY_RUN"; then
            run stow -n -v -d "$REPOSITORY_DIR" -R -t "$TARGET_HOME" "$package"
        else
            run stow -d "$REPOSITORY_DIR" -R -t "$TARGET_HOME" "$package"
        fi
    done
}

install_sddm() {
    if [[ "$EUID" -ne 0 ]]; then
        printf '%s\n' 'Error: --with-sddm must be run as root.' >&2
        exit 1
    fi

    local source="$REPOSITORY_DIR/sddm"
    local theme_root="/usr/share/sddm/themes/silent"
    local file destination

    [[ -d "$source" ]] || {
        printf '%s\n' 'Error: sddm directory is missing.' >&2
        exit 1
    }

    # The repository contains only the Cyberpunk overlay for SilentSDDM. If
    # the base theme is missing, install it through the invoking user's AUR
    # helper rather than trying to run an AUR helper as root.
    if [[ ! -f "$theme_root/Main.qml" ||
          ! -f "$theme_root/metadata.desktop" ||
          ! -d "$theme_root/components" ]]; then
        local aur_helper=''

        if command -v yay >/dev/null 2>&1; then
            aur_helper='yay'
        elif command -v paru >/dev/null 2>&1; then
            aur_helper='paru'
        fi

        if [[ "$TARGET_USER" == root || -z "$TARGET_USER" || -z "$TARGET_HOME" || -z "$aur_helper" ]]; then
            printf '%s\n' 'Error: the SilentSDDM base theme is missing.' >&2
            printf '%s\n' 'Run `yay -S sddm-silent-theme` or `paru -S sddm-silent-theme` as your normal user.' >&2
            exit 1
        fi

        log "Installing SilentSDDM through $aur_helper as $TARGET_USER"
        run sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" "$aur_helper" -S --needed sddm-silent-theme

        if "$DRY_RUN"; then
            log 'Dry run: skipping SilentSDDM file verification'
        elif [[ ! -f "$theme_root/Main.qml" ||
                ! -f "$theme_root/metadata.desktop" ||
                ! -d "$theme_root/components" ]]; then
            printf '%s\n' 'Error: SilentSDDM installation did not provide the required theme files.' >&2
            exit 1
        fi
    fi

    # SDDM mirrors the target filesystem below the repository's sddm folder.
    # install(1) creates parent directories and applies predictable modes.
    while IFS= read -r -d '' file; do
        destination="/${file#"$source/"}"
        run install -Dm644 "$file" "$destination"
        log "Installed $destination"
    done < <(find "$source" -type f -print0)

    configure_sddm_theme
}

configure_sddm_theme() {
    local metadata="/usr/share/sddm/themes/silent/metadata.desktop"

    # SilentSDDM chooses one config through metadata.desktop. The package
    # defaults to default.conf, so explicitly select this repository's custom
    # Cyberpunk configuration after installing the overlay files.
    if grep -q '^ConfigFile=' "$metadata"; then
        run sed -i 's|^ConfigFile=.*|ConfigFile=configs/Cyberpunk.conf|' "$metadata"
    elif grep -q '^# ConfigFile=configs/Cyberpunk.conf$' "$metadata"; then
        run sed -i 's|^# ConfigFile=configs/Cyberpunk.conf$|ConfigFile=configs/Cyberpunk.conf|' "$metadata"
    else
        run sh -c 'printf "\nConfigFile=configs/Cyberpunk.conf\n" >> "$1"' sh "$metadata"
    fi

    log "Selected configs/Cyberpunk.conf for SilentSDDM"

    # SilentSDDM calls play() from onSourceChanged, before the media is loaded,
    # so the call is dropped and the video background stays on its first frame.
    # autoPlay starts playback once loading finishes.
    run sed -i 's|autoPlay: false|autoPlay: true|' /usr/share/sddm/themes/silent/Main.qml
    log "Enabled autoPlay for the SilentSDDM video background"
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                ;;
            --with-sddm)
                WITH_SDDM=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                printf 'Error: unknown option: %s\n\n' "$1" >&2
                usage >&2
                exit 2
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    setup_repository

    log 'Installing packages'
    install_packages

    log "Installing user configuration into $CONFIG_HOME"
    install_user_configs

    log 'Setting default applications'
    set_default_apps

    log 'Applying desktop settings'
    set_gsettings

    if "$WITH_SDDM"; then
        log 'Installing SDDM configuration'
        install_sddm
    fi

    log 'Installation complete'
}

main "$@"