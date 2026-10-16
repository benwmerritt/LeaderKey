import Cocoa
import Combine
import Defaults
import KeyboardShortcuts
import Settings
import Sparkle
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate, NSWindowDelegate {
  var controller: Controller!

  let statusItem = StatusItem()
  let config = UserConfig()

  var state: UserState!
  private var updaterController: SPUStandardUpdaterController!
  /// Installs a downloaded update and relaunches; held until Leader Key is idle.
  private var pendingUpdateInstall: (() -> Void)?
  private var panelHiddenObserver: AnyCancellable?
  private var isSettingsOpen = false
  /// URLs wait here until Leader Key has made its panel and loaded its config, the URL that
  /// launched it among them, since AppKit hands that over before applicationDidFinishLaunching.
  /// Nil once they have been handled.
  private var urlsBeforeReady: [URL]? = []

  lazy var settingsWindowController = SettingsWindowController(
    panes: [
      Settings.Pane(
        identifier: .general, title: "General",
        toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!,
        contentView: { GeneralPane().environmentObject(self.config) }
      ),
      Settings.Pane(
        identifier: .advanced, title: "Advanced",
        toolbarIcon: NSImage(named: NSImage.advancedName)!,
        contentView: {
          AdvancedPane().environmentObject(self.config)
        }),
    ],
    style: .segmentedControl,
  )

  func applicationDidFinishLaunching(_: Notification) {

    guard
      ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    else { return }
    guard !isRunningTests() else { return }

    // Created here rather than in the storyboard, which would start it as the nib loads,
    // so a test run never checks for or installs updates.
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    panelHiddenObserver = Events.sink { [weak self] event in
      if event == .didDeactivate { self?.installPendingUpdateIfIdle() }
    }

    NSApp.mainMenu = MainMenu()

    let hadNoConfig = config.ensureAndLoad { self.handleURLsBeforeReady() }
    state = UserState(userConfig: config)
    controller = Controller(userState: state, userConfig: config)

    statusItem.handlePreferences = {
      self.showSettings()
    }
    statusItem.handleAbout = {
      NSApp.orderFrontStandardAboutPanel(nil)
    }
    statusItem.handleReloadConfig = {
      self.config.reloadFromFile()
    }
    statusItem.handleRevealConfig = {
      NSWorkspace.shared.activateFileViewerSelecting([self.config.url])
    }
    statusItem.handleCheckForUpdates = {
      self.updaterController.checkForUpdates(nil)
    }

    Task {
      for await value in Defaults.updates(.showMenuBarIcon) {
        if value {
          self.statusItem.enable()
        } else {
          self.statusItem.disable()
        }
      }
    }

    // Initialize status item according to current preference
    if Defaults[.showMenuBarIcon] {
      statusItem.enable()
    } else {
      statusItem.disable()
    }

    // Activation policy is managed solely by the Settings window

    registerGlobalShortcuts()

    // Only a first run opens Settings: while it is open, a downloaded update cannot install.
    if hadNoConfig {
      showSettings()
    }
  }

  func activate() {
    if self.controller.window.isKeyWindow {
      switch Defaults[.reactivateBehavior] {
      case .hide:
        self.hide()
      case .reset:
        self.controller.userState.clear()
      case .nothing:
        return
      }
    } else if self.controller.window.isVisible {
      // should never happen as the window will self-hide when not key
      self.controller.window.makeKeyAndOrderFront(nil)
    } else {
      self.show()
    }
  }

  public func registerGlobalShortcuts() {
    KeyboardShortcuts.removeAllHandlers()

    KeyboardShortcuts.onKeyDown(for: .activate) {
      self.activate()
    }

    for groupKey in Defaults[.groupShortcuts] {
      print("Registering shortcut for \(groupKey)")
      KeyboardShortcuts.onKeyDown(for: KeyboardShortcuts.Name("group-\(groupKey)")) {
        if !self.controller.window.isVisible {
          self.activate()
        }
        self.processKeys([groupKey])
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    // Config saves automatically on changes
  }

  // Opening Leader Key while it runs shows Settings: the way back in for a Mac with neither a
  // menu-bar icon nor a shortcut.
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showSettings()
    return false
  }

  @IBAction
  func settingsMenuItemActionHandler(_: NSMenuItem) {
    showSettings()
  }

  func show() {
    controller.show()
  }

  func hide() {
    controller.hide()
  }

  // MARK: - Updates

  /// Sparkle calls this once an automatic update has downloaded. Left to Sparkle, it installs
  /// only when the app quits, which a menu-bar app seldom does. Installing relaunches the app,
  /// so it waits until neither the panel, Settings nor a modal window such as a URL action's text
  /// box is open; Sparkle still installs it at quit if that comes first.
  func updater(
    _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    pendingUpdateInstall = immediateInstallHandler
    installPendingUpdateIfIdle()
    return true
  }

  /// Called when an update is ready, when the panel hides and when Settings closes.
  private func installPendingUpdateIfIdle() {
    guard let install = pendingUpdateInstall else { return }
    guard controller?.window?.isVisible != true, !isSettingsOpen, NSApp.modalWindow == nil
    else { return }
    pendingUpdateInstall = nil
    install()
  }

  func isRunningTests() -> Bool {
    let environment = ProcessInfo.processInfo.environment
    guard environment["XCTestSessionIdentifier"] != nil else { return false }
    return true
  }

  // MARK: - URL Scheme Handling

  func application(_ application: NSApplication, open urls: [URL]) {
    guard urlsBeforeReady == nil else {
      urlsBeforeReady?.append(contentsOf: urls)
      return
    }
    urls.forEach(handleURL)
  }

  private func handleURLsBeforeReady() {
    let urls = urlsBeforeReady ?? []
    urlsBeforeReady = nil
    urls.forEach(handleURL)
  }

  private func handleURL(_ url: URL) {
    let action = URLSchemeHandler.parse(url)

    switch action {
    case .settings:
      showSettings()
    case .about:
      NSApp.orderFrontStandardAboutPanel(nil)
    case .configReload:
      config.reloadFromFile()
    case .configReveal:
      NSWorkspace.shared.selectFile(config.path, inFileViewerRootedAtPath: "")
    case .activate:
      activate()
    case .hide:
      hide()
    case .reset:
      state.clear()
    case .navigate(let keys, let execute):
      show()
      processKeys(keys, execute: execute)
    case .show:
      show()
    case .invalid:
      return
    }
  }

  /// A key bound to nothing the panel shows ends the sequence, so the keys after it never land in
  /// a group they weren't meant for.
  private func processKeys(_ keys: [String], execute: Bool = true) {
    guard let key = keys.first, controller.handleKey(key, execute: execute), keys.count > 1 else {
      return
    }

    delay(100) { [weak self] in
      self?.processKeys(Array(keys.dropFirst()), execute: execute)
    }
  }

  // MARK: - Activation Policy: Only Settings Visibility Controls It

  private func showSettings() {
    isSettingsOpen = true
    // Behave like a normal app while Settings is open
    NSApp.setActivationPolicy(.regular)
    settingsWindowController.show()
    NSApp.activate(ignoringOtherApps: true)
    settingsWindowController.window?.delegate = self
  }

  // Revert to accessory when Settings window closes
  func windowWillClose(_ notification: Notification) {
    guard let win = notification.object as? NSWindow,
      win == settingsWindowController.window
    else { return }
    NSApp.setActivationPolicy(.accessory)
    isSettingsOpen = false
    installPendingUpdateIfIdle()
  }
}
