# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

# Leader Key Development Guide

## Build & Test Commands

Builds and tests need macOS with Xcode. From a Linux host, test through the gate, which runs on mbp16.

- Release build, ad-hoc signed, left at `build/Leader Key.app`: `bin/build`
- Install a build into `/Applications` (quits, backs up, relaunches): `bin/install [APP]`
- Lint and run every test: `~/fleet/bin/agent-gate run`. It runs the commands in `.agent-gate.json` on mbp16 against the committed HEAD, so commit first: it refuses a tree with uncommitted or untracked files. Passed when it exits 0 and prints `checks passed`.
- Run one test, on a Mac: the `xcodebuild test` command in `.agent-gate.json` plus `-only-testing:"Leader KeyTests/UserConfigTests/testInitializesWithDefaults"`
- Bump version: `bin/bump`

## Architecture Overview

Leader Key is a macOS application that provides customizable keyboard shortcuts. The core architecture consists of:

**Key Components:**

- `AppDelegate`: Application lifecycle, global shortcuts registration, URL scheme handling
- `Controller`: Central event handling, manages key sequences and window display
- `UserConfig`: JSON configuration management with validation
- `UserState`: Tracks navigation through key sequences
- `MainWindow`: Base class for theme windows

**Theme System:**

- Themes inherit from `MainWindow` and implement `draw()` method
- Available themes: MysteryBox, Mini, Breadcrumbs, ForTheHorde, Cheater
- Each theme provides different visual representations of shortcuts

**Configuration Flow:**

- Config stored at `~/Library/Application Support/Leader Key/config.json`
- `FileMonitor` watches for changes and triggers reload
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

