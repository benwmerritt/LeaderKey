# Running actions

Pressing an action's key runs it: an application opens, a shell command runs, or a URL opens in its app. The panel closes first, unless the user holds the sticky-mode modifier, which runs the action and keeps the panel open for the next one. A URL with a placeholder such as `{query}` first asks for the text in a small box.

## Sub-features

- `action-application` opens the application at the action's path and closes the panel.
- `action-command` runs the command through the user's shell and closes the panel.
- `action-url` opens the URL in the app that handles its scheme and closes the panel.
- `action-sticky` runs an action with the sticky-mode modifier held (Option by default) and keeps the panel open on the same list.
- `action-placeholder` asks for `{query}`-style text in a box titled with the action's label, then opens the URL with the text percent-encoded.
- `action-placeholder-cancel` opens nothing when the box is cancelled with escape or its Cancel button.

## How to get to it (user POV)

- Open the panel, move into a group if needed, and press the action's key.
- Hold the sticky-mode modifier (Settings, Option or Control) while pressing the key.
- Send `leaderkey://navigate?keys=o,c`, which presses the keys in turn and runs the action it lands on.

## Driving it with lk-verify

Preconditions:

- Baseline from `README.md`, any theme.
- `drive "$RUN" running Calculator` printed `Calculator: not running`. When it is running, the application step cannot prove the launch; skip it and say so.

- **Application.** Press `c`. Run `drive "$RUN" show key c measure after-app running Calculator`. `after-app: no on-screen Leader Key window` and `Calculator: running`. Then `drive "$RUN" quit Calculator`.
- **Command.** Press `t`. Run `drive "$RUN" marker show key t measure after-command marker`. The first `marker: absent`, then no Leader Key window and `marker: present`.
- **Sticky.** Hold Option and press `t`. Run `drive "$RUN" show measure before-sticky sticky t measure after-sticky marker escape`. `after-sticky` lists the same window as `before-sticky`, and `marker: present`.
- **Placeholder box.** Press `g`. Run `drive "$RUN" show key g measure box shot box`. One 340.0x124.0 window, centred across, with `midY-offset` a sixth of the visible height (145.0 on mba13). The shot shows its title, "Search the repo".
- **Cancel the box.** Press escape in the box. Run `drive "$RUN" escape measure cancelled`. `cancelled: no on-screen Leader Key window`, and no browser opened.
- **Fill the box.** Type a query and press return. Run `drive "$RUN" show key g key "tab key" return wait 3`, then read the browser on mba13, which is Chrome: `ssh mba13 "osascript -e 'tell application \"Google Chrome\" to get URL of active tab of front window'"`. GitHub redirects the opened URL to `https://github.com/search?q=repo%3Abenwmerritt%2FLeaderKey+tab+key&type=issues`. Close that tab with `ssh mba13 "osascript -e 'tell application \"Google Chrome\" to if URL of active tab of front window contains \"LeaderKey+tab+key\" then close active tab of front window'"`.
- **Navigate URL.** Run `drive "$RUN" running Calculator url "leaderkey://navigate?keys=o,c" wait 2 running Calculator`. Not running before, running after. Then `drive "$RUN" quit Calculator`.

## Gotchas

- The command action blocks Leader Key until the command exits, and a non-zero exit opens an alert that takes the keyboard.
- The box takes the keyboard, so the panel closes even in sticky mode. That is intended.
- A filled placeholder makes a real web request from mba13 and leaves a Chrome tab open. The cancel path proves the box without either.
- The fixture has no folder action, because it would open a Finder window no step closes. To verify one, begin with `--config` pointing at a config that has a `folder` action and take a `screen` shot.
- `quit` only the apps the run launched. `running` before the action is the record of what was already open.
