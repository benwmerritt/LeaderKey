import Defaults

/// Stored by raw value. A value written by a build that had more themes fails
/// `init(rawValue:)`, so Defaults falls back to the key's default, Mini.
enum Theme: String, Defaults.Serializable {
  case mini
  case cheater

  static var all: [Theme] {
    return [.mini, .cheater]
  }

  static func classFor(_ value: Theme) -> MainWindow.Type {
    switch value {
    case .mini:
      return Mini.Window.self
    case .cheater:
      return Cheater.Window.self
    }
  }

  static func name(_ value: Theme) -> String {
    switch value {
    case .mini: return "Mini"
    case .cheater: return "Cheater"
    }
  }
}
