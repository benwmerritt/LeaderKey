# Cheater panel

With the Cheater theme, Leader Key opens one panel in the middle of the screen listing every key in the current group with its label and icon. Pressing a group key swaps the list for that group, and the panel resizes to fit while staying centred and on screen. Escape closes it.

## Sub-features

- `cheater-open` opens the panel centred in the visible frame of the screen the `screen` setting picks (the primary screen by default).
- `cheater-group` swaps the list for a group's actions and resizes the panel, still centred and inside the visible frame.
- `cheater-back` returns to the root list on backspace and recentres.
- `cheater-unbound` shakes the panel on a key with no binding and keeps the current list.
- `cheater-close` closes the panel on escape, or when another app takes focus.
- `cheater-rows` shows each row's icon and detail, and inlines group contents when Settings asks for it.

## How to get to it (user POV)

- Press the activation shortcut recorded in Settings (F14 on mba13).
- Send `leaderkey://activate` from another tool. A second `activate` while the panel has focus closes it, resets it or does nothing, per the "reactivate" setting.
- Send `leaderkey://show`, which only ever opens it.
- Send `leaderkey://navigate?keys=o&execute=false`, which opens it straight into a group.

## Driving it with lk-verify

Preconditions:

- Baseline from `README.md`, begun with `--theme cheater`.

- **Open with the shortcut.** Press the activation shortcut. Run `drive "$RUN" shortcut measure root shot root`. One 580.0x168.0 window, `midX-offset` and `midY-offset` within 0.5 point of 0, `past-bottom=0.0` and `past-top=0.0`. The shot lists `c`, `o`, `t`, `l` and `g` with their labels.
- **Into a group.** Press `o`. Run `drive "$RUN" key o measure open-apps shot open-apps`. The window grows to 580.0x469.0, still centred, nothing past the top or bottom. The shot lists the 13 apps and the `u` "Utilities" group.
- **Nested group.** Press `u`. Run `drive "$RUN" key u measure utilities shot utilities`. The window shrinks to 580.0x133.0 for two rows (Console, Disk Utility) and stays centred.
- **Back to the root.** Press backspace. Run `drive "$RUN" backspace measure back`. 580.0x168.0 again, centred.
- **Unbound key.** Press `z`. Run `drive "$RUN" key z measure unbound`. Still one 580.0x168.0 window, centred.
- **Close.** Press escape. Run `drive "$RUN" escape measure closed`. `closed: no on-screen Leader Key window`.
- **Other entry points.** Repeat the open step with `activate`, then with `show`, then with `url "leaderkey://navigate?keys=o&execute=false"`, closing with `escape` each time. Each opens the panel centred; the last opens on the 580.0x469.0 "Open Apps" list.
- **Row options.** `set "$RUN" expandGroupsInCheatsheet -bool true`, then `drive "$RUN" show measure expanded shot expanded escape`. The root grows past 168 points and the shot shows the "Open Apps" contents inline. `showAppIconsInCheatsheet` and `showDetailsInCheatsheet` (both on by default) toggle the icons and the detail line the same way.

## Gotchas

- Sizes above are for `fixtures/config.json` on mba13. Another config, or a change to row layout, moves them; the offsets and the past-edge values are what prove centring.
- Offsets of up to 0.5 point are rounding from centring on whole points, not drift.
- `?` does nothing in this theme. The panel is itself the cheatsheet.
- mba13 has one 1440x900 screen, so the `screen` setting's mouse and active-window choices cannot be told apart from primary there.
