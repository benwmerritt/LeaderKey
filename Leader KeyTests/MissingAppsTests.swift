import Defaults
import XCTest

@testable import Leader_Key

final class MissingAppsTests: XCTestCase {
  private let installed = "/Applications/Installed.app"
  private let missing = "/Applications/Missing.app"

  private func app(_ key: String, _ path: String) -> ActionOrGroup {
    .action(Action(key: key, type: .application, value: path))
  }

  private func group(_ key: String, _ actions: [ActionOrGroup]) -> ActionOrGroup {
    .group(Group(key: key, actions: actions))
  }

  private func visible(_ actions: [ActionOrGroup]) -> Group {
    Group(key: nil, actions: actions).withoutMissingApps { $0 == self.installed }
  }

  private func keys(_ group: Group) -> [String?] {
    group.actions.map { $0.item.key }
  }

  func testHidesAnApplicationWhoseAppIsMissing() {
    XCTAssertEqual(keys(visible([app("i", installed), app("m", missing)])), ["i"])
  }

  func testLeavesURLCommandAndFolderActionsAlone() {
    let others: [ActionOrGroup] = [
      .action(Action(key: "u", type: .url, value: "https://example.com")),
      .action(Action(key: "c", type: .command, value: "/no/such/command")),
      .action(Action(key: "f", type: .folder, value: "/no/such/folder")),
    ]

    XCTAssertEqual(
      Group(key: nil, actions: others).withoutMissingApps { _ in false }.actions, others)
  }

  func testHidesMissingAppsInsideNestedGroups() {
    let root = visible([
      group("o", [app("i", installed), app("m", missing), group("n", [app("j", installed)])])
    ])

    guard case .group(let o) = root.actions.first else { return XCTFail("group o is hidden") }
    XCTAssertEqual(keys(o), ["i", "n"])
  }

  func testHidesAGroupWhoseEveryDescendantIsMissing() {
    let root = visible([
      group("a", [app("m", missing), group("b", [app("n", missing)])]),
      group("c", [app("i", installed)]),
    ])

    XCTAssertEqual(keys(root), ["c"])
  }

  func testKeepsAGroupConfiguredEmpty() {
    XCTAssertEqual(keys(visible([group("e", [])])), ["e"])
  }

  func testChecksTheConfiguredPath() {
    var checked: [String] = []
    _ = Group(key: nil, actions: [app("i", installed), group("g", [app("m", missing)])])
      .withoutMissingApps {
        checked.append($0)
        return true
      }

    XCTAssertEqual(checked, [installed, missing])
  }
}

final class VisibleRootTests: XCTestCase {
  private var tempDir: String!
  private var originalSuite: UserDefaults!
  private var config: UserConfig!
  private var state: UserState!

  override func setUp() {
    super.setUp()
    originalSuite = defaultsSuite
    defaultsSuite = UserDefaults(suiteName: UUID().uuidString)!
    tempDir = NSTemporaryDirectory().appending("LeaderKeyTests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    Defaults[.configDir] = tempDir

    config = UserConfig(alertHandler: TestAlertManager())
    state = UserState(userConfig: config)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(atPath: tempDir)
    defaultsSuite = originalSuite
    super.tearDown()
  }

  func testShowsAnAppInstalledSinceTheLastRefresh() throws {
    let appPath = (tempDir as NSString).appendingPathComponent("Later.app")
    config.root = Group(
      key: nil, actions: [.action(Action(key: "l", type: .application, value: appPath))])

    state.refreshVisibleRoot()
    XCTAssertTrue(state.visibleRoot.actions.isEmpty)

    try FileManager.default.createDirectory(atPath: appPath, withIntermediateDirectories: true)
    state.refreshVisibleRoot()
    XCTAssertEqual(state.visibleRoot.actions.map { $0.item.key }, ["l"])
  }

  func testKeepsEveryKeyInTheConfig() {
    let missingPath = (tempDir as NSString).appendingPathComponent("Missing.app")
    let root = Group(
      key: nil,
      actions: [
        .group(
          Group(
            key: "g", actions: [.action(Action(key: "m", type: .application, value: missingPath))]))
      ])
    config.root = root

    state.refreshVisibleRoot()

    XCTAssertTrue(state.visibleRoot.actions.isEmpty)
    XCTAssertEqual(config.root, root)
  }
}
