# Working agreement for this repo

## Setup
- Hyprland on CachyOS, configs are GNU Stow packages linked into `~/.config`.
- Branch `master`: public (`origin`), laptop setup, everything shared by both machines.
- Branch `pc`: private (`private` remote), the PC's playful theme. Shared fixes go to
  `master` first, then `git merge master` into `pc`.
- Task list: `TODO.md` on the `pc` branch. Read it at the start of a session and tick
  items you finish there.

## Reliability first (no loose ends)
- Every program, font, cursor or icon a config references must be installed and listed
  in the package list used by `scripts/install.sh`. Adding a dependency means adding it there.
- No dangling symlinks, no leftover references to removed tools, no unlinked configs.
- After changing configs, verify (run the check script once it exists) and report
  failures plainly.

## No assumptions
- Taste, app choices and anything machine-specific are the user's call: ask, one question
  at a time, with a recommendation. Don't guess and build.
- State which branch a change belongs on before making it.

## Design decisions
- The user decides the look. Present options as a tiny self-contained HTML file
  (named color swatches, a small mockup of bar/window/terminal), not as hex lists.
  Save it in the scratchpad and open it with `xdg-open`.
- Taste so far: ComicShannsMono Nerd Font everywhere; flat, precisely aligned, thin
  borders, one playful accent; no widget overload, no glossy glow.
- No AI-generated wallpapers. Credit each wallpaper's artist in `CREDITS.md`
  (pc branch only, wallpapers are not published).

## Token economy
- Read only the files a task needs; no broad surveys or long option lists.
- Short answers, small commits per logical step so each can be reverted.
