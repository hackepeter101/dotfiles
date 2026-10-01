# Dark Arasaka dotfiles for Arch/CachyOS

## Colors:

- background: #050209
- text: #c4ede9
- accent: #e41148
- deep red: #c9032f
- muted: #595c61
- warning: #ffd23f

The active palette is defined in `hyprland/.config/hypr/config/colors.lua` and
is reused by the GTK, Rofi, Kitty, SwayNC, Waybar, and Hyprland layers.

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

There is install.sh file but i dont recomend runing it for now as it is made by ai...
SDDM files are kept separate because they install under system paths.
