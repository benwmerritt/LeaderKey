# Leader Key verification map

This directory is the maintained source for verifying what a Leader Key user sees and does. Read this index before driving the app, then use the matching feature file as the recipe. Every command is `lk-verify` from `../SKILL.md`.

## Baseline preconditions

- `lk-verify stage` built the tree under test and printed `$RUN`.
- `lk-verify begin "$RUN"` printed `running <version> (<build>) with theme <theme>`, with the theme the feature file names and `fixtures/config.json` unless the file says otherwise. Every other setting is at the app's default; the activation shortcut is mba13's own.
- `lk-verify doctor "$RUN"` shows the lock held by `$RUN`, the build running and no other Leader Key copy.
- The panel is closed, at the root of the config.

## Driving conventions

- Start each recipe from the baseline. A recipe that changes a default does it with `lk-verify set`, which relaunches the build.
- Open the panel the way the entry point under test does: `shortcut`, `activate`, `show` or `navigate`.
- Steps are literal. Keys are the fixture's keys, and labels are the fixture's labels.
- A recipe ends with the panel closed, so the next one starts from the baseline.

## Proof and skip reporting

- Pair each action with its result: a `measure` and a `shot` before and after every step that should change the panel. Where `shot` cannot run (see the Screen Recording gotcha in `../SKILL.md`), drop the `shot` steps and cite the `measure` lines.
- A side effect gets its own check beside the screen: `marker` for the command action, `running APP` for an application action.
- Record the feature's sub-feature IDs and the entry point beside the evidence you cite.
- Report an unreachable entry point with the step you ran and what blocked it. An entry point verified through a different one stays unverified.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behaviour. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behaviour.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with lk-verify` starts with `Preconditions:` and uses labelled bullets that pair each user action with an exact `drive` step and the observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only user paths, keys, required state, steps and observable proof.

## Features

- [Cheater panel](./cheater-panel.md) covers opening the Cheater theme's panel, moving through groups, centring as it resizes, unbound keys and closing it.
- [Mini panel and cheatsheet](./mini-cheatsheet.md) covers the Mini theme's corner panel and the cheatsheet that opens above it.
- [Running actions](./actions.md) covers application, command and URL actions, sticky mode and the placeholder box.
- [URL commands](./url-commands.md) covers the `leaderkey://` commands other tools send.
