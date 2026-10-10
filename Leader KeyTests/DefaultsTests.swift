import Defaults
import XCTest

@testable import Leader_Key

/// Preferences written by earlier builds must still read as something this build understands.
final class DefaultsTests: XCTestCase {
  func testThemeDefaultsToMini() {
    XCTAssertEqual(Defaults.Keys.theme.defaultValue, .mini)
  }

  func testRemovedThemesDecodeToMini() {
    for stored in ["mysteryBox", "breadcrumbs", "forTheHorde"] {
      XCTAssertEqual(decode(.theme, stored: stored), .mini, "stored theme \(stored)")
    }
  }

  func testLegacyModifierConfigurationKeepsItsStickyModifier() {
    XCTAssertEqual(decode(.stickyModeModifier, stored: "controlGroupOptionSticky"), .option)
    XCTAssertEqual(decode(.stickyModeModifier, stored: "optionGroupControlSticky"), .control)
  }

  func testStickyModifierRoundTripsAndFallsBackToOption() {
    XCTAssertEqual(decode(.stickyModeModifier, stored: "control"), .control)
    XCTAssertEqual(decode(.stickyModeModifier, stored: "option"), .option)
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
