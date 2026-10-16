# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

# Leader Key Development Guide

## Build & Test Commands

Builds and tests need macOS with Xcode. Edit on agentmini; build and test on mba13 over SSH. mba13 has the Command Line Tools selected, not Xcode, so the scripts default `DEVELOPER_DIR` to `/Applications/Xcode.app/Contents/Developer`; set it yourself for any other `xcodebuild` call there. For script smoke tests, rsync the tree into a `mktemp -d` on mba13 and run there.

- Lint and run every test: `bin/check`. From agentmini, run it on mba13 against the committed HEAD with `~/fleet/bin/qa-exec --host mba13 --evidence "$(mktemp -u)" --command bin/check`. qa-exec refuses a tree with uncommitted or untracked files, so commit first. Passed when it exits 0 and prints `checks passed`.
- Run one test: pass `-only-testing` to `bin/check`. From agentmini: `~/fleet/bin/qa-exec --host mba13 --evidence "$(mktemp -u)" --command 'bin/check -only-testing:"Leader KeyTests/UserConfigTests/testInitializesWithDefaults"'`
- Release build, ad-hoc signed, left at `build/Leader Key.app`: `bin/build`. Like a release's, its build number is the commit count, which is what Sparkle compares to decide whether a release is newer.
- Signed release build exactly as CI makes it, left at `build/release/Leader-Key-<version>.zip`: `SIGNING_P12=<path> SIGNING_P12_PASSWORD="$(cat <password file>)" bin/release-build`, reading the password from a file so that no command line carries it. The `.p12` and its password live outside the repository. A change to `bin/release-build`, `bin/release-appcast`, `signing/` or `.github/workflows/release.yml` gets this smoke test on mba13 before it ships.
- Install a build into `/Applications` (quits, backs up, relaunches): `bin/install [APP]`. To bootstrap a Mac, `scp` the `.app` and the script there and run it over SSH: scp sets no quarantine flag, so Gatekeeper never sees the unnotarised app.
- Drive a build the way a user does, to prove a change to the panel, a theme, the cheatsheet, an action or a `leaderkey://` command: the `verify-leaderkey` skill (`.agents/skills/verify-leaderkey/SKILL.md`). It builds on mba13, presses keys, measures and screenshots the panel, and restores the installed app.
- A smoke test that quits Leader Key or touches its defaults on mba13 holds the lock first: `ssh mba13 'mkdir /tmp/leaderkey-smoke.lock && echo "<branch> $(date -u +%FT%TZ)" > /tmp/leaderkey-smoke.lock/owner'`. When mkdir fails, read the owner file, wait and retry. Release it with `ssh mba13 'rm -rf /tmp/leaderkey-smoke.lock'` once the installed app and its defaults are back. `verify-leaderkey` takes and releases it itself, and `bin/check` runs through qa-exec need none, since they never touch the installed app.

## Releases

Tag a commit on `main` as `vX.Y.Z` and push the tag. `.github/workflows/release.yml` builds and signs the app on a GitHub macOS runner, generates `appcast.xml`, and publishes a GitHub release holding the zip and the appcast. A tag outside `main`'s history fails the run, because the build number is the commit count and must only grow. Sparkle on the Macs reads `releases/latest/download/appcast.xml`, downloads a new release in the background, and installs it by relaunching Leader Key once the panel and Settings are closed, or at quit. On every pull request to `main` the same build and appcast run as a dry run, signed with a throwaway certificate and Sparkle key made in the job, and land in a workflow artifact instead of a release.

- Signing uses a self-signed certificate: no Apple Developer account, no notarisation. The project stays ad-hoc so anyone can build; only `bin/release-build` applies the certificate. `signing/designated-requirement.txt` pins the signature's designated requirement, which is what lets macOS permissions survive updates; a different certificate gives a different requirement and the script fails instead of shipping it.
- The signing secrets live in the `release` GitHub environment, which only `v*` tags may use, so pull-request runs never see them. The Sparkle key's public half is `SUPublicEDKey` in `Leader Key/Support/Info.plist`.

## Architecture Overview

Leader Key is a macOS application that provides customizable keyboard shortcuts. The core architecture consists of:

**Key Components:**

- `AppDelegate`: Application lifecycle, global shortcuts registration, URL scheme handling, the Sparkle updater
- `Controller`: Central event handling, manages key sequences and window display
- `UserConfig`: JSON or TOML configuration management with validation
- `UserState`: Tracks navigation through key sequences
- `MainWindow`: Base class for theme windows

**Theme System:**

- Themes inherit from `MainWindow` and implement `draw()` method
- Available themes: Mini, Cheater
- Each theme provides different visual representations of shortcuts

**Configuration Flow:**

- Config stored at `~/Library/Application Support/Leader Key/config.json`; a symlink there is written through, so a dotfiles manager can own the file
- A `config.toml` beside it wins for as long as it exists (`ConfigFormat`, codec in `TOMLConfig.swift`). It is hand-edited: while it is live `UserConfig` writes neither file and the Settings editor is read-only
- Config reloads only on request: the menu-bar "Reload config" item, the Settings "Read from file" button, `leaderkey://config-reload`, and the save-conflict alert's "Read from File". Nothing watches the file
- `ConfigValidator` ensures no key conflicts
- Actions support: applications, URLs, commands, folders

**Testing Architecture:**

- Uses XCTest with custom `TestAlertManager` for UI testing
- Tests use isolated UserDefaults and temporary directories
- Focus on configuration validation and state management

## Code Style Guidelines

- **Naming**: Use descriptive camelCase for variables/functions, PascalCase for types
- **Types**: Use explicit type annotations for public properties and parameters
- **Error Handling**: Use appropriate error handling with do/catch blocks and alerts
- **Extensions**: Create extensions for additional functionality on existing types
- **State Management**: Use @Published and ObservableObject for reactive UI updates
- **Testing**: Create separate test cases with descriptive names, use XCTAssert\* methods
- **Access Control**: Use appropriate access modifiers (private, fileprivate, internal)
- **Documentation**: Use comments for complex logic or non-obvious implementations

Formatting belongs to swift-format's defaults (2-space indentation, alphabetically sorted imports, 100-column lines): the `Format` build phase applies them to `Leader Key` and `Leader KeyTests` on every build, and the gate lints with `--strict`.
