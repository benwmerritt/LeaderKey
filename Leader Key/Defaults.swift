import Cocoa
import Defaults

var defaultsSuite =
  ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  ? UserDefaults(suiteName: UUID().uuidString)!
  : .standard

extension Defaults.Keys {
  static let configDir = Key<String>(
    "configDir", default: UserConfig.defaultDirectory(), suite: defaultsSuite)
  static let showMenuBarIcon = Key<Bool>(
    "showInMenubar", default: true, suite: defaultsSuite)
  // Stored under the name the setting had when it also chose the group-execution modifier,
  // so a preference written by an earlier build still applies.
  static let stickyModeModifier = Key<StickyModeModifier>(
    "modifierKeyConfiguration", default: .option, suite: defaultsSuite)
  static let theme = Key<Theme>(
    "theme", default: .mini, suite: defaultsSuite)

  static let autoOpenCheatsheet = Key<AutoOpenCheatsheetSetting>(
    "autoOpenCheatsheet",
    default: .delay, suite: defaultsSuite)
  static let cheatsheetDelayMS = Key<Int>(
    "cheatsheetDelayMS", default: 2000, suite: defaultsSuite)
  static let expandGroupsInCheatsheet = Key<Bool>(
    "expandGroupsInCheatsheet", default: false, suite: defaultsSuite)
  static let showAppIconsInCheatsheet = Key<Bool>(
    "showAppIconsInCheatsheet", default: true, suite: defaultsSuite)
  static let showDetailsInCheatsheet = Key<Bool>(
    "showDetailsInCheatsheet", default: true, suite: defaultsSuite)
  static let showFaviconsInCheatsheet = Key<Bool>(
    "showFaviconsInCheatsheet", default: true, suite: defaultsSuite)
  static let reactivateBehavior = Key<ReactivateBehavior>(
    "reactivateBehavior", default: .hide, suite: defaultsSuite)
  static let screen = Key<Screen>(
    "screen", default: .primary, suite: defaultsSuite)

  static let groupShortcuts = Key<Set<String>>(
    "groupShortcuts",
    default: Set(), suite: defaultsSuite)
}

enum AutoOpenCheatsheetSetting: String, Defaults.Serializable {
  case never
  case always
  case delay
}

/// The modifier held while triggering an action to keep Leader Key open afterwards.
enum StickyModeModifier: String, Defaults.Serializable, CaseIterable, Identifiable {
  case option
  case control

  /// Earlier builds stored one of two combined values that also chose the modifier for
  /// running a whole group; each named the sticky modifier in its second half.
  init?(rawValue: String) {
    switch rawValue {
    case "option", "controlGroupOptionSticky": self = .option
    case "control", "optionGroupControlSticky": self = .control
    default: return nil
    }
  }

  var id: Self { self }

  var modifierFlag: NSEvent.ModifierFlags {
    switch self {
    case .option: return .option
    case .control: return .control
    }
  }

  var description: String {
    switch self {
    case .option: return "⌥ Option"
    case .control: return "⌃ Control"
    }
  }
}

enum ReactivateBehavior: String, Defaults.Serializable {
  case hide
  case reset
  case nothing
}

enum Screen: String, Defaults.Serializable {
  case primary
  case mouse
  case activeWindow
}
