# About this fork

This is [benwmerritt](https://github.com/benwmerritt)'s personal build of [mikker/LeaderKey](https://github.com/mikker/LeaderKey): the same app and bundle ID, built and signed by this fork's GitHub Actions with a self-signed certificate. Updates come from [this fork's releases](https://github.com/benwmerritt/LeaderKey/releases): the app's Sparkle updater reads their feed, downloads new versions in the background and installs them by relaunching Leader Key while its panel and Settings are closed. Nothing is notarised, so a Mac gets its first copy through `bin/install` (after `bin/build`, or from a release zip) rather than by double-clicking a download. The fork also reads a [TOML config](#a-toml-config). Everything after that section is upstream's README, except [placeholders in URL actions](#placeholders-in-url-actions), which only this fork has.

## A TOML config

Leader Key keeps its config in `config.json`, in the config directory that Settings → Advanced shows. Put a `config.toml` beside it and Leader Key reads that instead, ignoring `config.json` for as long as `config.toml` exists. To go back, delete or rename `config.toml` and choose Read from file. A `config.toml` that doesn't load shows its error, the way a broken `config.json` does; Leader Key never quietly falls back to `config.json`.

The quickest start is the Convert to TOML button in Settings → Advanced. It writes your current config as `config.toml` beside `config.json`, leaves `config.json` as it is, and switches to the new file. It refuses, and says why, when a `config.toml` is already there or the config has issues to fix first.

Each menu is a table named by the keys that open it, and each binding in it is named by the key you press:

```toml
t = { app = "/System/Applications/Utilities/Terminal.app" }

[o]
label = "Open"
icon = "folder"
s   = { app = "/Applications/Safari.app" }
d   = { folder = "~/Downloads", label = "Downloads" }
"," = { url = "x-apple.systempreferences:", label = "System Settings" }

[o.m]
label = "Messages"
m = { app = "/System/Applications/Messages.app" }
w = { url = "https://web.whatsapp.com/", label = "WhatsApp" }

[r]
h = { cmd = 'say "hello"' }
```

Here <kbd>leader</kbd><kbd>o</kbd><kbd>m</kbd><kbd>w</kbd> opens WhatsApp.

- A binding holds exactly one of `app` (an application's path), `url`, `cmd` (a shell command) or `folder`, which says what it does, plus an optional `label` (the name shown for it) and `icon` (an SF Symbol name, or the path of an app whose icon to use).
- A table with none of those four is a menu. Its own `label` and `icon` describe it, and every other key in it is a binding.
- A key that isn't a letter, digit, `-` or `_` goes in quotes: `","`, `"["`, `"'"`. Special keys go by name: `space`, `enter`, `tab`, `delete`, `left`, `right`, `up` and `down`.
- A string in single quotes is taken literally, which saves escaping a command full of double quotes or backslashes.
- File order is menu order. TOML puts a table's own lines before the tables inside it, so a binding that comes after a submenu can't be a one-liner in its menu's table and gets a section of its own instead. This `o` menu lists Safari, then the Messages menu, then Downloads:

  ```toml
  [o]
  s = { app = "/Applications/Safari.app" }

  [o.m]
  m = { app = "/System/Applications/Messages.app" }

  [o.d]
  folder = "~/Downloads"
  ```

  You can write every binding that way if you prefer; the two styles mix freely.
- Writing the same key twice in one menu is a load error, and the error names the line.

While `config.toml` is live, the Config list in Settings is read-only: browse it there, edit the file, then choose Read from file (or run `open "leaderkey://config-reload"`). Reveal in Settings, Show config in Finder in the menu bar and `leaderkey://config-reveal` all show `config.toml`.

---

# NB: Leader Key has been surpassed by [Tuna](https://tunaformac.com)

Tuna is a complete launcher – much more capable, and with **Leader Key built in!**

[![Meet Tuna](https://img.youtube.com/vi/vkm-ZFlivyI/mqdefault.jpg)](https://www.youtube.com/watch?v=vkm-ZFlivyI)

[Leader Key will stay free and open source](https://github.com/mikker/LeaderKey/discussions/314#discussioncomment-15939059) but my focus will be on Tuna going forward. 

---
  
<img src="https://s3.brnbw.com/icon_1024-akc2Ij3q9JOyhQ6Y7Lz6AFkX6nQQFhrQaRPqbV4vor0A62EA0vq4xOGrXpg6PVKi3aUJxOAyItkyktblPtZD4K4oYZ1bJVdh96VE.png" width="256" height="256" alt="Leader Key.app" />

**The \*faster than your launcher\* launcher**

A riff on [Raycast](https://www.raycast.com), [@mxstbr's multi-key Karabiner setup](https://www.youtube.com/watch?v=m5MDv9qwhU8&t=540s), and Vim's `<leader>` key.

Watch the intro video on YouTube:

<div>
<a href="https://www.youtube.com/watch?v=EQYakLsYSAQ"><img src="https://img.youtube.com/vi/EQYakLsYSAQ/maxresdefault.jpg" width=480></a>
<a href="https://www.youtube.com/watch?v=hzzQl5FOL-k"><img src="https://img.youtube.com/vi/hzzQl5FOL-k/maxresdefault.jpg" width=480></a>
</div>

*Yes, I only have that one thumbnail face.*

## Install

**Download**

📦 [Download latest version](https://github.com/mikker/LeaderKey.app/releases)
or

**Homebrew**

```sh
$ brew install leader-key
```

### Post-Install setup
- Open the settings menu with the menu bar icon <img width="17" alt="Screenshot 2025-05-21 at 1 58 46 PM" src="https://github.com/user-attachments/assets/7ba2cd99-dbd1-4b23-a35b-c5579e797321" />
- Choose your [`leader`](#what-do-i-set-as-my-leader-key) (`Shortcut` that will open the app) 

  <img width="213" alt="Screenshot 2025-05-21 at 2 01 56 PM" src="https://github.com/user-attachments/assets/5e486a9a-ee1c-4ac7-a2d9-f4d0a46eb734" />
- Add your [shortcuts](#example-shortcuts) to the `Config` settings

## Why Leader Key?

### Problems with traditional launchers:

1. Typing the name of the thing can be slow and give unpredictable results.
2. Global shortcuts have limited combinations.
3. Leader Key offers predictable, nested shortcuts -- like combos in a fighting game.

### Example Shortcuts:

- <kbd>leader</kbd><kbd>o</kbd><kbd>m</kbd> → Launch Messages (`open messages`)
- <kbd>leader</kbd><kbd>m</kbd><kbd>m</kbd> → Mute audio (`media mute`)
- <kbd>leader</kbd><kbd>w</kbd><kbd>m</kbd> → Maximize current window (`window maximize`)

## Placeholders in URL actions

A URL action can leave parts of its URL to be filled in each time it runs:

```json
{ "key": "g", "type": "url", "label": "Search Google", "value": "https://google.com/search?q={query}" }
```

| Placeholder | Filled with |
|---|---|
| `{clipboard}` | The text on the clipboard, without leading or trailing whitespace. When the clipboard holds no text, Leader Key asks for it instead. |
| `{argument}`, `{query}`, `{search query}` | Text you type into a box titled with the action's label. |
| `{argument name="Topic"}` | The same, with `Topic` shown in the box. |

- Letter case doesn't matter: `{Query}` and `{query}` are the same placeholder.
- A placeholder used more than once in a URL is asked for once.
- Cancel, <kbd>Esc</kbd> or clicking another app closes the box and opens nothing.
- The box takes the keyboard, so in sticky mode it closes the panel.
- Every character outside `A–Z`, `a–z`, `0–9` and `-._~` is percent-encoded, so a value with `&`, `#`, `/` or spaces stays inside the query, path or fragment it lands in.
- Anything else in braces, such as `{id}` or `{argument name="X" default="Y"}`, is left as written.

Placeholders work in URL actions only; command actions run as written.

## URL Scheme

Leader Key supports URL scheme automation for integration with tools like Alfred, Raycast, shell scripts, and more.

### Available URL Schemes

#### Configuration Management
```bash
# Reload configuration from disk
open "leaderkey://config-reload"

# Show config.json in Finder
open "leaderkey://config-reveal"
```

#### Window Control
```bash
# Show Leader Key window
open "leaderkey://activate"

# Hide Leader Key window
open "leaderkey://hide"

# Clear navigation state (return to root)
open "leaderkey://reset"
```

#### Settings & Info
```bash
# Open settings window
open "leaderkey://settings"

# Show about dialog
open "leaderkey://about"
```

#### Navigation
```bash
# Navigate through keys and execute actions
open "leaderkey://navigate?keys=a,b,c"

# Navigate without executing (preview mode)
open "leaderkey://navigate?keys=a,b,c&execute=false"
```

### Example Use Cases

- **Alfred/Raycast workflows**: Trigger Leader Key shortcuts programmatically
- **Shell scripts**: Automate configuration reloads after editing config.json
- **Keyboard maestro**: Chain Leader Key actions with other automations
- **External triggers**: Open specific action sequences from other applications

## FAQ

#### What do I set as my Leader Key?

Any key can be your leader key, but **only modifiers will not work**.

**Examples:**

- <kbd>F12</kbd>
- <kbd>⌘ + space</kbd>
- <kbd>⌘⌥ + space</kbd>
- <kbd>⌘⌥⌃⇧ + L</kbd> (hyper key)

**Advanced examples:**

Using [Karabiner](https://karabiner-elements.pqrs.org/) you can do more fancy things like:

- <kbd>right ⌘ + left ⌘</kbd> at once (bound to <kbd>F12</kbd>) my personal favorite
- <kbd>caps lock</kbd> (bound to <kbd>hyper</kbd> when held, <kbd>F12</kbd> when pressed)

See [@mikker's config](https://github.com/mikker/LeaderKey.app/wiki/@mikker's-config) in the wiki for akimbo cmds example.

#### I disabled the menubar item, how can I get Leader Key back?

Activate Leader Key, then <kbd>cmd + ,</kbd>.

#### Command action is failing with "Command not found"

You need to make sure your shell environment is correctly set up for non-interactive mode, and exports the `PATH` variable.

**For zsh** make sure you have your `PATH` variable exported in `~/.zshenv`

**For bash** make sure you have your `PATH` variable exported in `~/.bash_profile`


## License

MIT
