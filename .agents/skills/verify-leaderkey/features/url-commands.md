# URL commands

Other tools (Raycast, Alfred, shell scripts) control Leader Key by opening `leaderkey://` URLs. They open, toggle, close and reset the panel, press keys in it, reload the config from disk, and open Settings or About.

## Sub-features

- `url-show` opens the panel, and leaves it open when it already is.
- `url-activate` opens the panel, and on a second send while it has focus closes it (the default "reactivate" setting).
- `url-hide` closes the panel.
- `url-reset` returns an open panel to the root list.
- `url-navigate` opens the panel and presses each key in `keys=`, running the action it lands on; `execute=false` stops on the action instead.
- `url-config-reload` reads the config file again, so an edit made on disk shows in the panel.
- `url-settings` opens Settings, and `url-about` opens the About window with the version and build.
- `url-unknown` treats any other host, such as `leaderkey://anything`, as `show`.
- `url-cold-launch` launches Leader Key when it is not running, then does what the URL asks once it has finished launching.

## How to get to it (user POV)

- `open "leaderkey://<command>"` from a shell, or a Raycast or Alfred action that opens the URL.
- The same, while Leader Key is not running.

## Driving it with lk-verify

Preconditions:

- Baseline from `README.md`, begun with `--theme cheater` so the panel shows labels and sizes per list.

- **Show.** Run `drive "$RUN" show measure shown show measure still-shown`. Both list the same window.
- **Activate toggles.** Run `drive "$RUN" hide activate measure opened activate measure toggled`. `opened` lists the panel; `toggled` prints no on-screen Leader Key window.
- **Hide.** Run `drive "$RUN" show hide measure hidden`. No on-screen Leader Key window.
- **Reset.** Run `drive "$RUN" show key o measure in-group reset measure reset`. `in-group` is the taller "Open Apps" size; `reset` is back to the root size, still open.
- **Navigate without running.** Run `drive "$RUN" url "leaderkey://navigate?keys=o,u&execute=false" measure utilities shot utilities escape`. The panel is open on the two-row "Utilities" list.
- **Navigate and run.** Run `drive "$RUN" marker navigate t measure navigated marker`. `marker: absent`, then no Leader Key window and `marker: present`.
- **Reload the config.** Delete the `l` line from the run's config on mba13, then reload. Run `ssh mba13 "sed -i '' '/\"key\": \"l\"/d' /private/tmp/lk-verify-$RUN/config/config.json"`, then `drive "$RUN" config-reload show measure reloaded escape`. `reloaded` is 580.0x140.0, one row shorter than the 168.0 root. Every later recipe in the run sees the edited config, so run this one last or `begin` a fresh run after it.
- **About.** Run `drive "$RUN" about measure about shot about`. A 284.0x170.0 window; the shot shows the version and build that `doctor` reported for the run.
- **Settings.** Run `drive "$RUN" settings wait 2 measure settings shot settings` as the last step before `end`. A 780.0x752.0 window; the shot shows Settings.
- **Unknown host.** Run `drive "$RUN" url "leaderkey://anything" measure unknown escape`. The panel is open.
- **Cold launch.** Run `drive "$RUN" cold leaderkey://show measure cold-show escape cold "leaderkey://navigate?keys=o&execute=false" measure cold-navigate escape`. `cold-show` is the 580.0x168.0 root panel and `cold-navigate` the 580.0x469.0 "Open Apps" list, each centred. A build that crashes instead stops the drive with "this run's build is not running".

## Gotchas

- `leaderkey://config-reveal` opens a Finder window no step closes. It has no recipe here.
- About and Settings stay open after the step, escape closes neither, and the key guard counts them as Leader Key windows, so later key steps would type into them. End the run after them, or `set` any key to relaunch the build.
- Settings takes more than a second to appear, so a `measure` straight after `settings` finds no window. Wait 2 seconds first.
- `navigate` sends its keys 100 ms apart. Give a long `keys=` list a `wait` before measuring.
