import Defaults
import XCTest

@testable import Leader_Key

/// Preferences written by earlier builds must still read as something this build understands.
final class DefaultsTests: XCTestCase {
  func testThemeDefaultsToMini() {
    XCTAssertEqual(Defaults.Keys.theme.defaultValue, .mini)
  }

  func testKeptThemesDecode() {
    XCTAssertEqual(decode(.theme, stored: "mini"), .mini)
    XCTAssertEqual(decode(.theme, stored: "cheater"), .cheater)
  }

  func testRemovedThemesDecodeToMini() {
    for stored in ["mysteryBox", "breadcrumbs", "forTheHorde"] {
      XCTAssertEqual(decode(.theme, stored: stored), .mini, "stored theme \(stored)")
    }
  }

  /// The exact strings earlier builds stored, quotes included.
  func testLegacyModifierConfigurationKeepsItsStickyModifier() {
    XCTAssertEqual(decode(.stickyModeModifier, stored: #""controlGroupOptionSticky""#), .option)
    XCTAssertEqual(decode(.stickyModeModifier, stored: #""optionGroupControlSticky""#), .control)
  }

  /// Pins the quoted form above to what Defaults writes for a type shaped like the old one.
  func testDefaultsStoredTheLegacyTypeAsQuotedJSON() {
    let suiteName = UUID().uuidString
    let suite = UserDefaults(suiteName: suiteName)!
    defer { suite.removePersistentDomain(forName: suiteName) }
    let key = Defaults.Key<LegacyModifierKeyConfig>(
      "modifierKeyConfiguration", default: .controlGroupOptionSticky, suite: suite)

    Defaults[key] = .optionGroupControlSticky

    XCTAssertEqual(suite.string(forKey: key.name), #""optionGroupControlSticky""#)
  }

  func testStickyModifierRoundTripsAsPlainRawValue() {
    let key = Defaults.Keys.stickyModeModifier
    defer { key.suite.removeObject(forKey: key.name) }

    for modifier in StickyModeModifier.allCases {
      Defaults[key] = modifier
      XCTAssertEqual(key.suite.string(forKey: key.name), modifier.rawValue)
      XCTAssertEqual(Defaults[key], modifier)
    }
  }

  func testUnknownStickyModifierFallsBackToOption() {
    XCTAssertEqual(decode(.stickyModeModifier, stored: "nonsense"), .option)
  }

  /// Writes `stored` straight into the key's suite, as an older build would have, and reads it
  /// back through Defaults.
  private func decode<Value: Defaults.Serializable>(
    _ key: Defaults.Key<Value>, stored: String
  ) -> Value {
    key.suite.set(stored, forKey: key.name)
    defer { key.suite.removeObject(forKey: key.name) }
    return Defaults[key]
  }
}

/// The shape of the setting before sticky mode got its own type.
private enum LegacyModifierKeyConfig: String, Codable, Defaults.Serializable {
  case controlGroupOptionSticky
  case optionGroupControlSticky
}
