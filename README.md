# Dark Arasaka dotfiles for Arch/CachyOS

## Colors:

- background: #050209
- text: #c4ede9
- accent: #e41148
- deep red: #c9032f
- muted: #595c61
- warning: #ffd23f

Hyprland reads these colors from `hyprland/.config/hypr/config/colors.lua`; the
other apps (GTK, Rofi, Kitty, SwayNC, Waybar) repeat the hex values in their own
config files.

Font: ComicShannsMono Nerd Font everywhere.

Configuration roots:

- `hyprland/.config/hypr`: compositor, monitors, workspaces, and window rules
- `gtk/.config`: GTK 3/4 settings and CSS
- `waybar/.config/waybar`: status bar configuration
- `rofi/.config/rofi`: application launcher configuration
- `swaync/.config/swaync`: notification center configuration
- `kitty/.config/kitty`: terminal configuration

Monitor settings are shared by default. For machine-specific outputs or
scaling, create `~/.config/hypr-monitors.lua`; it should return a table with
`monitors` and `workspaces` entries matching the structure in
`hyprland/.config/hypr/config/monitors.lua`.

Dependencies are declared in `setup/`:

- `packages-repo.txt` / `packages-aur.txt`: every package the configs use
- `default-apps.txt`: default applications, applied with `xdg-mime`
- `stow-packages.txt`: the Stow packages that get linked into `$HOME`
- `gsettings.txt`: font, cursor and dark mode for apps that ignore `settings.ini`

`scripts/install.sh` installs and links all of it (try `--dry-run` first).
`scripts/doctor.sh` checks a machine against the repository: missing packages,
fonts, cursor, unlinked or dangling config files, and default apps.
SDDM files are kept separate because they install under system paths.

## Disclaimer

The configs and the look are mine. The setup and check scripts
(`scripts/install.sh`, `scripts/doctor.sh`, `setup/`) and some config fixes
were written with AI assistance (Claude); those commits are marked
`Co-Authored-By: Claude`. Read `install.sh` before running it, or start
with `--dry-run`.
