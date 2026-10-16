# Mini panel and cheatsheet

With the Mini theme, Leader Key opens a small square in the bottom-right corner of the screen showing the current group's key, a dot at the root. A cheatsheet listing the group's keys opens above the square, right edges aligned, after a delay, at once, or only on `?`, as Settings chooses. It follows the square as the list changes size.

## Sub-features

- `mini-open` opens a 36 by 36 point square 8 points in from the right and bottom of the visible frame.
- `mini-group` shows the group's key in the square after a group key.
- `mini-cheatsheet-delay` opens the cheatsheet after `cheatsheetDelayMS` (2000 by default) with no key pressed; each key press restarts the wait.
- `mini-cheatsheet-always` opens the cheatsheet with the square when "auto-open" is `always`.
- `mini-cheatsheet-never` opens the cheatsheet only on `?` when "auto-open" is `never`.
- `mini-cheatsheet-anchor` keeps the cheatsheet 8 points above the square with right edges aligned, including after it resizes for another group.
- `mini-close` closes the square and the cheatsheet together on escape.

## How to get to it (user POV)

- Press the activation shortcut, or send `leaderkey://activate` or `leaderkey://show`.
- Press `?` with the square open to bring the cheatsheet up early.
- Choose the auto-open behaviour and delay in Settings.

## Driving it with lk-verify

Preconditions:

- Baseline from `README.md`, begun with `--theme mini`.
- `autoOpenCheatsheet` and `cheatsheetDelayMS` at their defaults (`delay`, 2000) unless a step sets them.

- **Open.** Press the shortcut. Run `drive "$RUN" shortcut measure square`. One 36.0x36.0 window with `right` 8 less than `visible right` and `bottom` 8 more than `visible bottom` (1432.0 and 8.0 on mba13).
- **Delayed cheatsheet.** Wait out the delay. Run `drive "$RUN" wait 2 measure delayed shot delayed`. Two windows: the square, and the cheatsheet with the same `right` and a `bottom` 8 above the square's `top` (52.0 on mba13). The shots show the root list and a dot in the square.
- **Group resizes it.** Press `o`. Run `drive "$RUN" key o measure open-apps shot open-apps`. The cheatsheet grows to 580.0x469.0 with the same `right` and `bottom`; the square shows `o`.
- **Close.** Press escape. Run `drive "$RUN" escape measure closed`. `closed: no on-screen Leader Key window`.
- **Question mark.** `set "$RUN" autoOpenCheatsheet never`, then `drive "$RUN" show wait 3 measure no-sheet key "?" measure sheet escape`. `no-sheet` lists only the square; `sheet` lists both windows.
- **Always.** `set "$RUN" autoOpenCheatsheet always`, then `drive "$RUN" show measure always escape`. Both windows on the first measure.

## Gotchas

- Until the cheatsheet opens, every key press restarts the `delay` timer, so measure it at least `cheatsheetDelayMS` after the last key. Once open, it stays open through group changes.
- `measure` and `shot` list windows front to back, which puts the cheatsheet before the square: `NAME.png` is the cheatsheet and `NAME-2.png` the square.
