# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

# Leader Key Development Guide

## Build & Test Commands

Builds and tests need macOS with Xcode. Edit on agentmini; build and test on mba13 over SSH. mba13 has the Command Line Tools selected, not Xcode, so the scripts and the gate default `DEVELOPER_DIR` to `/Applications/Xcode.app/Contents/Developer`; set it yourself for any other `xcodebuild` call there. For script smoke tests, rsync the tree into a `mktemp -d` on mba13 and run there.

- Lint and run every test: `~/fleet/bin/agent-gate run`. It runs the commands in `.agent-gate.json` on mba13 against the committed HEAD, so commit first: it refuses a tree with uncommitted or untracked files. Passed when it exits 0 and prints `checks passed`.
- Run one test, on a Mac: the `xcodebuild test` command in `.agent-gate.json` plus `-only-testing:"Leader KeyTests/UserConfigTests/testInitializesWithDefaults"`
- Release build, ad-hoc signed, left at `build/Leader Key.app`: `bin/build`
- Signed release build exactly as CI makes it, left at `build/release/Leader-Key-<version>.zip`: `SIGNING_P12=<path> SIGNING_P12_PASSWORD=<password> bin/release-build`. The `.p12` and its password live outside the repository. A change to `bin/release-build`, `signing/` or `.github/workflows/release.yml` gets this smoke test on mba13 before it ships.
- Install a build into `/Applications` (quits, backs up, relaunches): `bin/install [APP]`. To bootstrap a Mac, `scp` the `.app` and the script there and run it over SSH: scp sets no quarantine flag, so Gatekeeper never sees the unnotarised app.
- Bump version: `bin/bump`

## Releases

Tag a commit on `main` as `vX.Y.Z` and push the tag. `.github/workflows/release.yml` builds and signs the app on a GitHub macOS runner, generates `appcast.xml`, and publishes a GitHub release holding the zip and the appcast. Sparkle on the Macs reads `releases/latest/download/appcast.xml` and installs the update without asking. On every pull request to `main` the same workflow runs as a dry run and uploads the zip and appcast as a workflow artifact instead of publishing.

- Signing uses a self-signed certificate: no Apple Developer account, no notarisation. The project stays ad-hoc so anyone can build; only `bin/release-build` applies the certificate. `signing/designated-requirement.txt` pins the signature's designated requirement, which is what lets macOS permissions survive updates; a different certificate gives a different requirement and the script fails instead of shipping it.
- Repository secrets: `MACOS_SIGNING_P12_BASE64`, `MACOS_SIGNING_P12_PASSWORD`, `SPARKLE_ED_PRIVATE_KEY`. The matching public key is `SUPublicEDKey` in `Leader Key/Support/Info.plist`.

## Architecture Overview

Leader Key is a macOS application that provides customizable keyboard shortcuts. The core architecture consists of:

**Key Components:**

- `AppDelegate`: Application lifecycle, global shortcuts registration, URL scheme handling, Sparkle update reminders
- `Controller`: Central event handling, manages key sequences and window display
- `UserConfig`: JSON configuration management with validation
- `UserState`: Tracks navigation through key sequences
- `MainWindow`: Base class for theme windows

**Theme System:**

- Themes inherit from `MainWindow` and implement `draw()` method
- Available themes: MysteryBox, Mini, Breadcrumbs, ForTheHorde, Cheater
- Each theme provides different visual representations of shortcuts

**Configuration Flow:**

- Config stored at `~/Library/Application Support/Leader Key/config.json`; a symlink there is written through, so a dotfiles manager can own the file
- Config reloads on activation and on `leaderkey://config-reload`; nothing watches the file
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
