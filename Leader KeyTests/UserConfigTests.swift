import Defaults
import XCTest

@testable import Leader_Key

class TestAlertManager: AlertHandler {
  var shownAlerts: [(style: NSAlert.Style, message: String)] = []

  func showAlert(style: NSAlert.Style, message: String) {
    shownAlerts.append((style: style, message: message))
  }

  func showAlert(
    style: NSAlert.Style, message: String, informativeText: String, buttons: [String]
  ) -> NSApplication.ModalResponse {
    shownAlerts.append((style: style, message: message))
    return .alertFirstButtonReturn
  }

  func reset() {
    shownAlerts = []
  }
}

final class UserConfigTests: XCTestCase {
  var tempBaseDir: String!
  var testAlertManager: TestAlertManager!
  var subject: UserConfig!
  var originalSuite: UserDefaults!

  override func setUp() {
    super.setUp()

    // Create a temporary UserDefaults suite for testing
    originalSuite = defaultsSuite
    defaultsSuite = UserDefaults(suiteName: UUID().uuidString)!

    // Create a unique temporary directory for each test
    tempBaseDir = NSTemporaryDirectory().appending("/LeaderKeyTests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(atPath: tempBaseDir, withIntermediateDirectories: true)

    testAlertManager = TestAlertManager()
    subject = UserConfig(alertHandler: testAlertManager)

    // Set the config directory to our temp directory by default
    Defaults[.configDir] = tempBaseDir
  }

  override func tearDown() {
    try? FileManager.default.removeItem(atPath: tempBaseDir)
    testAlertManager.reset()

    // Restore original UserDefaults suite
    defaultsSuite = originalSuite

    subject = nil
    super.tearDown()
  }

  func testInitializesWithDefaults() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertNotEqual(subject.root, emptyRoot)
    XCTAssertTrue(subject.exists)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
  }

  func testCreatesDefaultConfigDirIfNotExists() throws {
    let defaultDir = UserConfig.defaultDirectory()
    // Remove both directory and config file
    try? FileManager.default.removeItem(atPath: defaultDir)
    try? FileManager.default.removeItem(
      atPath: (defaultDir as NSString).appendingPathComponent("config.json"))
    Defaults[.configDir] = defaultDir

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertTrue(FileManager.default.fileExists(atPath: defaultDir))
    XCTAssertTrue(subject.exists)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
    XCTAssertNotEqual(subject.root, emptyRoot)  // Verify the config was parsed successfully
  }

  func testResetsToDefaultDirWhenCustomDirDoesNotExist() throws {
    let nonExistentDir = tempBaseDir.appending("/DoesNotExist")
    Defaults[.configDir] = nonExistentDir

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertEqual(Defaults[.configDir], UserConfig.defaultDirectory())
    XCTAssertEqual(testAlertManager.shownAlerts.count, 1)
    XCTAssertEqual(testAlertManager.shownAlerts[0].style, .warning)
    XCTAssertTrue(
      testAlertManager.shownAlerts[0].message.contains("Config directory does not exist"))
    XCTAssertTrue(subject.exists)
  }

  func testShowsAlertWhenConfigFileFailsToParse() throws {
    // First ensure we're in the default directory since custom dirs are no longer supported
    Defaults[.configDir] = UserConfig.defaultDirectory()

    let invalidJSON = "{ invalid json }"
    try invalidJSON.write(to: subject.url, atomically: true, encoding: .utf8)

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertEqual(subject.root, emptyRoot)
    XCTAssertGreaterThan(testAlertManager.shownAlerts.count, 0)
    // Verify that at least one warning alert was shown (JSON parsing errors are non-critical)
    XCTAssertTrue(
      testAlertManager.shownAlerts.contains { alert in
        alert.style == .warning
      })
  }

  func testValidationIssuesDoNotTriggerAlerts() throws {
    let json = """
      {
        "actions": [
          { "key": "a", "type": "application", "value": "/Applications/Safari.app" },
          { "key": "a", "type": "url", "value": "https://example.com" }
        ]
      }
      """

    try json.write(to: subject.url, atomically: true, encoding: .utf8)

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertFalse(subject.validationErrors.isEmpty)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)

    testAlertManager.reset()
    subject.saveConfig()

    XCTAssertFalse(subject.validationErrors.isEmpty)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
  }

  // MARK: - Symlinked config

  func testSavingThroughSymlinkKeepsLinkAndUpdatesTarget() throws {
    let target = try makeSymlinkedConfig()

    subject.ensureAndLoad()
    waitForConfigLoad()
    XCTAssertEqual(subject.root.actions.count, 1)

    subject.root.actions.append(addedAction)
    waitForDebouncedSave()

    XCTAssertTrue(isSymlink(subject.path), "save replaced the symlink with a plain file")
    XCTAssertEqual(savedKeys(at: target), ["a", "z"])
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
  }

  func testDetectsExternalChangeThroughSymlink() throws {
    let target = try makeSymlinkedConfig()

    subject.ensureAndLoad()
    waitForConfigLoad()

    try externalConfig.write(toFile: target, atomically: true, encoding: .utf8)
    subject.saveConfig()

    XCTAssertEqual(testAlertManager.shownAlerts.count, 1)
    XCTAssertTrue(testAlertManager.shownAlerts[0].message.contains("changed on disk"))
    // TestAlertManager answers "Overwrite", so the save goes ahead, through the link.
    XCTAssertTrue(isSymlink(subject.path))
    XCTAssertEqual(savedKeys(at: target), ["a"])
  }

  func testSavingPlainFileStaysPlainFile() throws {
    try initialConfig.write(toFile: subject.path, atomically: true, encoding: .utf8)

    subject.ensureAndLoad()
    waitForConfigLoad()

    subject.root.actions.append(addedAction)
    waitForDebouncedSave()

    XCTAssertFalse(isSymlink(subject.path))
    XCTAssertEqual(savedKeys(at: subject.path), ["a", "z"])

    try externalConfig.write(toFile: subject.path, atomically: true, encoding: .utf8)
    subject.saveConfig()

    XCTAssertEqual(testAlertManager.shownAlerts.count, 1)
    XCTAssertTrue(testAlertManager.shownAlerts[0].message.contains("changed on disk"))
  }

  private let initialConfig = """
    {
      "actions": [{ "key": "a", "type": "url", "value": "https://a.example" }]
    }
    """
  private let externalConfig = """
    {
      "actions": [{ "key": "b", "type": "url", "value": "https://b.example" }]
    }
    """
  private let addedAction = ActionOrGroup.action(
    Action(key: "z", type: .url, value: "https://z.example"))

  /// Writes `initialConfig` to `<temp>/dotfiles/config.json` and points `<temp>/config.json`
  /// at it through a relative symlink, the shape stow and similar tools produce.
  /// Returns the target's path.
  private func makeSymlinkedConfig() throws -> String {
    let fileManager = FileManager.default
    let targetDir = tempBaseDir.appending("/dotfiles")
    try fileManager.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
    let target = targetDir.appending("/config.json")
    try initialConfig.write(toFile: target, atomically: true, encoding: .utf8)
    try fileManager.createSymbolicLink(
      atPath: subject.path, withDestinationPath: "dotfiles/config.json")
    return target
  }

  private func isSymlink(_ path: String) -> Bool {
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    return attributes?[.type] as? FileAttributeType == .typeSymbolicLink
  }

  /// The top-level keys in the config file at `path`, in file order.
  private func savedKeys(at path: String) -> [String] {
    guard let data = FileManager.default.contents(atPath: path),
      let group = try? JSONDecoder().decode(Group.self, from: data)
    else { return [] }
    return group.actions.compactMap { $0.item.key }
  }

  private func waitForConfigLoad() {
    let expectation = expectation(description: "config load flush")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: 1.0)
  }

  /// Editing `root` saves on a 300 ms debounce, then writes on a background queue.
  private func waitForDebouncedSave() {
    let expectation = expectation(description: "debounced save flush")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: 2.0)
  }
}
