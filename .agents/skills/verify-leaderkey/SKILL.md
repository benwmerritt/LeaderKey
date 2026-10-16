---
name: verify-leaderkey
description: Builds a Leader Key tree on mba13 and drives the real app the way a user does, with key presses, actions and leaderkey:// URLs, then measures and screenshots the panel. Use to prove a change to the panel, a theme, the cheatsheet, an action or a URL command, or to reproduce a bug someone saw on screen.
---

# Verify Leader Key

`scripts/lk-verify` runs on agentmini and does the work on mba13 over SSH. It builds a tree there, swaps the installed Leader Key for that build, drives the build with real key presses and URLs, then puts the installed app and its settings back exactly. Evidence lands in `.verify/<run>/evidence/` in this checkout, which git ignores.

Every command below is `.agents/skills/verify-leaderkey/scripts/lk-verify`, shortened to `lk-verify`.

Ground rules:

- Drive mba13 only. mbp14 and mbp16 are Ben's working Macs.
- One run at a time owns mba13, through the smoke-test lock `/tmp/leaderkey-smoke.lock` that other agents' smoke tests share. `begin` takes it and `end` releases it, so every drive sits between the two. A lock whose owner file names another run belongs to that run: wait for it.
- The installed `/Applications/Leader Key.app` belongs to Sparkle. lk-verify quits it, runs its own build from `/private/tmp`, and relaunches the installed copy at `end`.
- Builds are ad-hoc (`bin/build`). A verify run never needs the release signing material.

## Launch

1. Stage a build. `RUN=$(lk-verify stage)` copies the working tree, uncommitted and untracked files included, to mba13 and builds it; `lk-verify stage --ref origin/main` builds a commit instead, for the before half of a before and after pair. A build takes a few minutes. stdout is the run id; the build log stays at `mba13:/private/tmp/lk-verify-$RUN/build.log`.
2. `lk-verify begin "$RUN" [--theme cheater|mini] [--config FILE]`. Cheater is the default theme and `fixtures/config.json` the default config. A `--config` file ending `.toml` lands as `config.toml`, so the build reads TOML. begin takes the lock, quits the installed app, snapshots Leader Key's defaults, points `configDir` at a copy of the config, turns off Sparkle's checks and launches the build. Ready when it prints `running <version> (<build>) with theme <theme>`; by then it has opened and closed the panel once, so the build answers. Exit status 75 means another run holds the lock: the message names the owner, so wait a minute and retry. Any other failure restores mba13 before begin exits.
3. Optional. `lk-verify set "$RUN" KEY [-TYPE] VALUE` writes one more Leader Key default and relaunches the build, as in `set "$RUN" autoOpenCheatsheet always` or `set "$RUN" showAppIconsInCheatsheet -bool true`. The keys are in `Leader Key/Defaults.swift`. begin's snapshot covers them, so `end` undoes them too.

The fixture config gives every feature recipe something to press:

| keys | action |
|---|---|
| `c` | Calculator |
| `o` | "Open Apps", 13 apps plus the `u` "Utilities" group (Console, Disk Utility) |
| `t` | "Mark the run", a command that touches `/private/tmp/lk-verify-marker` |
| `l` | "Leader Key repo", a URL |
| `g` | "Search the repo", a URL with a `{query}` placeholder |

## Doctor

`lk-verify doctor ["$RUN"]` is read-only. It prints the host and console user, the lock owner, the installed app's version and whether it runs, the run's build and whether it runs, any other Leader Key copy running, and the theme and `configDir` defaults. A run is worth driving when the console user is `ben`, the lock owner starts with this run's id, the build is running, and no other copy is listed. Run doctor without a run id before `begin` to see whether the lock is free, and with one whenever a step surprises you.

## Drive

`lk-verify drive "$RUN" STEP...` runs its steps in order in one SSH session and stops at the first failure. Every step that acts waits `LK_SETTLE` seconds afterwards, 1 by default.

| step | what it does |
|---|---|
| `show` `hide` `reset` `activate` `settings` `about` `config-reload` | opens `leaderkey://<step>` with this run's build |
| `navigate KEYS` | `leaderkey://navigate?keys=KEYS`, comma separated, which runs the action it lands on |
| `url URL` | opens any URL with this run's build, such as `leaderkey://navigate?keys=o,u&execute=false` |
| `key TEXT` | types TEXT |
| `sticky TEXT` | types TEXT holding the sticky-mode modifier, Option unless Settings chose Control |
| `backspace` `escape` `return` | presses that key |
| `wait SECONDS` | pauses |
| `measure LABEL` | one line per on-screen Leader Key window: size, edges, and offsets from the visible frame of its screen |
| `shot NAME` | screenshots each on-screen Leader Key window, front to back, to `NAME.png`, `NAME-2.png` and so on |
| `screen NAME` | screenshots the whole screen |
| `shortcut` | presses the activation shortcut recorded in Settings (F14 on mba13), the way a user opens the panel |
| `marker` | whether the "Mark the run" command has run |
| `running APP` / `quit APP` | whether a process named APP runs, or asks APP to quit |

Key steps refuse to type unless a Leader Key window is on screen. Leader Key hides its panel the moment it loses focus, so a window on screen is what proves the keys reach Leader Key and no other app on mba13. `shortcut` skips the guard, since opening the panel is its job.

The feature map in `features/README.md` holds a recipe per feature. Read it, pick the feature your change touches, and drive every entry point its file lists. `lk-verify fetch "$RUN"` copies the evidence so far without ending the run.

## Evidence

- Drive the user's path: the keys a user presses or the `leaderkey://` URL another tool sends.
- Pair each action with its result: `measure` and `shot` before and after every key that should change the panel.
- Check side effects beside the screen: `marker` after the command action, `running APP` before and after an application action.
- Prove a fix with a pair: stage `--ref origin/main` and the working tree, run the same steps against each run in turn, and compare their `measure` lines.
- Look at every screenshot with the Read tool before you cite it.

Each run's evidence directory holds `steps.log` (every step with its UTC time), `measure.log` (every `measure`, `marker` and `running` line) and the PNGs. `.verify/$RUN/run.env` records the source and build number. Screenshots go into a PR through `bwm-prs`'s visual evidence guide.

## Cleanup

1. When a `running APP` check showed an app was not running before the action launched it, `drive "$RUN" quit APP`. Apps that were already running stay.
2. `lk-verify end "$RUN"`, after a failed drive as much as a good one. It quits the build, clears Leader Key's defaults and imports the snapshot, relaunches the installed app if it had been running, releases the lock, and fetches the evidence. Done when it prints `Leader Key defaults restored exactly`, `installed app relaunched: <version>` (when it had been running) and `lock released`.
3. `lk-verify clean "$RUN"` unregisters the build from LaunchServices and deletes the run on mba13. The evidence in `.verify/$RUN/` stays.

When `end` cannot finish, run doctor and repair by hand on mba13: `defaults delete com.brnbw.Leader-Key && defaults import com.brnbw.Leader-Key /private/tmp/lk-verify-$RUN/defaults-before.plist`, then `open -a "/Applications/Leader Key.app"`, then `rm -rf /tmp/leaderkey-smoke.lock` once its owner file names this run.

## Helpers

- `scripts/lk-verify` is the entry point; run `lk-verify` with no arguments for usage. It needs git and `ssh mba13`. `LK_VERIFY_HOST` points it at another Mac with Xcode, `LK_SETTLE` changes the pause after each step.
- `scripts/remote.sh` is the mba13 half. lk-verify pipes it to `bash -s` on every call, so nothing is installed on mba13, and bash runs it whatever the login shell (zsh on mba13).
- `scripts/measure-panel.swift` is compiled into the run at `stage`; `measure`, `shot` and the key guard use it.
- `fixtures/config.json` is the default config.

## Gotchas

- `shot` and `screen` need Screen Recording for SSH sessions on mba13, which macOS grants only in System Settings > Privacy & Security > Screen & System Audio Recording, to `/usr/libexec/sshd-keygen-wrapper`. Without it they stop the drive with that message. Leave them out and cite the `measure` lines instead.
- A `leaderkey://` URL that reaches Leader Key while it is still launching, or that launches it, crashes it, and each later URL relaunches it into the same crash. begin and `set` wait until the build has made its windows; send URLs only to a running build.
- On mba13, System Events and `lsappinfo` report a ghost 1Password as the frontmost app, so a frontmost-app check says nothing. The window-on-screen guard is the check.
- A plain `open leaderkey://...` goes to whichever copy LaunchServices picks, often the installed app. The URL steps pass this run's build to `open -a`; use them.
- `navigate` runs the action it lands on. Add `&execute=false` through the `url` step to stop at the action instead.
