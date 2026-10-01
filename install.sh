#!/usr/bin/env bash

# Install the user-level configuration from this repository.
#
# The repository is intentionally kept as a collection of GNU Stow packages:
# each package contains files relative to $HOME. Stow links those files into
# the user's home directory so changes remain version-controlled here and are
# immediately visible to the applications using them.
#
# By default, only user configuration is installed. SDDM is installed only
# when --with-sddm is passed because it writes to system-owned directories.
# When this file is piped into Bash, the repository is cloned temporarily so
# GNU Stow can still access the package directories beside this script.

set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/hackepeter101/dotfiles.git"
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/hackepeter101/dotfiles/master/install.sh"
readonly CONFIG_HOME="$HOME/.config"

DRY_RUN=false
WITH_SDDM=false
TEMP_DIR=''
SCRIPT_DIR=''

setup_repository() {
    local script_path="${BASH_SOURCE[0]:-}"

    # With `curl URL/install.sh | bash`, Bash reads the script from stdin and
    # there is no local directory containing the Stow packages. Clone a
    # temporary checkout and remove it automatically when the script exits.
    if [[ -n "$script_path" && -f "$script_path" ]]; then
        SCRIPT_DIR="$(cd -- "$(dirname -- "$script_path")" && pwd)"
        return
    fi

    command -v git >/dev/null 2>&1 || {
        printf '%s\n' 'Error: git is required when install.sh is piped into Bash.' >&2
        exit 1
    }

    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf -- "$TEMP_DIR"' EXIT
    log "Cloning dotfiles into a temporary directory"
    git clone --depth 1 "$REPOSITORY_URL" "$TEMP_DIR/dotfiles"
    SCRIPT_DIR="$TEMP_DIR/dotfiles"
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

backup_config_dir() {
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
    local source config_entry destination

    for source in "$SCRIPT_DIR/$package/.config"/*; do
        [[ -e "$source" || -L "$source" ]] || continue
        config_entry="$(basename -- "$source")"
        destination="$CONFIG_HOME/$config_entry"

        # A link already pointing at this package is safe for Stow to restow.
        if [[ -L "$destination" && "$(readlink -f -- "$destination")" == "$source" ]]; then
            continue
        fi

        if [[ -e "$destination" || -L "$destination" ]]; then
            backup_config_dir "$destination"
        fi
    done
}

install_user_configs() {
    # Keep this list explicit so a future repository directory is not
    # installed accidentally just because it happens to contain .config.
    local packages=(cava fastfetch gtk hyprland kitty rofi swaync waybar)
    local package

    command -v stow >/dev/null 2>&1 || {
        printf '%s\n' 'Error: GNU Stow is required but was not found in PATH.' >&2
        exit 1
    }

    # Stow targets $HOME, so ~/.config must exist before any package is
    # restowed. This is harmless when the directory is already present.
    run mkdir -p "$CONFIG_HOME"

    for package in "${packages[@]}"; do
        if [[ ! -d "$SCRIPT_DIR/$package/.config" ]]; then
            printf 'Warning: skipping %s; no .config directory found\n' "$package" >&2
            continue
        fi

        prepare_package_conflicts "$package"
        if "$DRY_RUN"; then
            run stow -n -v -d "$SCRIPT_DIR" -R -t "$HOME" "$package"
        else
            run stow -d "$SCRIPT_DIR" -R -t "$HOME" "$package"
        fi
    done
}

install_sddm() {
    if [[ "$EUID" -ne 0 ]]; then
        printf '%s\n' 'Error: --with-sddm must be run as root.' >&2
        exit 1
    fi

    local source="$SCRIPT_DIR/sddm"
    local file destination

    [[ -d "$source" ]] || {
        printf '%s\n' 'Error: sddm directory is missing.' >&2
        exit 1
    }

    # SDDM mirrors the target filesystem below the repository's sddm folder.
    # install(1) creates parent directories and applies predictable modes.
    while IFS= read -r -d '' file; do
        destination="/${file#"$source/"}"
        run install -Dm644 "$file" "$destination"
        log "Installed $destination"
    done < <(find "$source" -type f -print0)
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

    log "Installing user configuration into $CONFIG_HOME"
    install_user_configs

    if "$WITH_SDDM"; then
        log 'Installing SDDM configuration'
        install_sddm
    fi

    log 'Installation complete'
}

main "$@"