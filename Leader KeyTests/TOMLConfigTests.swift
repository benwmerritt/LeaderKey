import XCTest

@testable import Leader_Key

final class TOMLConfigTests: XCTestCase {
  func testRoundTripsEveryShapeOfBinding() throws {
    let fromJSON = try JSONDecoder().decode(Group.self, from: Data(fixture.utf8))

    let text = TOMLConfig.encode(fromJSON)
    let fromTOML = try TOMLConfig.decode(text)

    XCTAssertTrue(fromTOML.hasSameConfig(as: fromJSON), "round trip changed the config:\n\(text)")
  }

  func testWritesMenusAsSections() {
    let root = Group(
      key: nil,
      actions: [
        .action(
          Action(key: "t", type: .application, value: "/System/Applications/Utilities/Terminal.app")
        ),
        .group(
          Group(
            key: "o", label: "Open", iconPath: "folder",
            actions: [
              .action(
                Action(key: ",", type: .url, label: "Settings", value: "x-apple.systempreferences:")
              ),
              .action(
                Action(key: "m", type: .application, value: "/System/Applications/Messages.app")),
              .group(
                Group(
                  key: "s", label: "Scripts",
                  actions: [.action(Action(key: "q", type: .command, value: #"say "hi""#))])),
              .action(
                Action(
                  key: "d", type: .folder, label: "Downloads", value: "~/Downloads",
                  iconPath: "arrow.down.circle")),
            ])),
      ])

    XCTAssertEqual(
      TOMLConfig.encode(root),
      #"""
      t = { app = "/System/Applications/Utilities/Terminal.app" }

      [o]
      label = "Open"
      icon = "folder"
      "," = { url = "x-apple.systempreferences:", label = "Settings" }
      m   = { app = "/System/Applications/Messages.app" }

      [o.s]
      label = "Scripts"
      q = { cmd = 'say "hi"' }

      [o.d]
      folder = "~/Downloads"
      label = "Downloads"
      icon = "arrow.down.circle"

      """#)
  }

  func testFileOrderIsMenuOrder() throws {
    let root = try TOMLConfig.decode(
      """
      z = { app = "/Applications/Zed.app" }
      b = { url = "https://b.example" }

      [m]
      label = "Menu"
      y = { cmd = "echo y" }

      [m.a]
      app = "/Applications/A.app"

      [m.c]
      k = { url = "https://k.example" }
      a = { url = "https://a.example" }

      [m.b]
      folder = "~/b"

      [a]
      url = "https://a.example"
      """)

    XCTAssertEqual(keys(root), ["z", "b", "m", "a"])
    let menu = try XCTUnwrap(subgroup("m", of: root))
    XCTAssertEqual(menu.label, "Menu")
    XCTAssertEqual(keys(menu), ["y", "a", "c", "b"])
    XCTAssertEqual(keys(try XCTUnwrap(subgroup("c", of: menu))), ["k", "a"])
  }

  // MARK: - Errors

  func testRejectsABindingWithTwoActions() {
    assertDecodeError(
      """
      [o.m.g]
      app = "/Applications/Ghostty.app"
      url = "https://ghostty.org"
      """,
      names: "[o.m.g]", "app and url")
  }

  func testRejectsAnUnknownField() {
    assertDecodeError(
      """
      [o.g]
      app = "/Applications/Ghostty.app"
      lable = "Ghostty"
      """,
      names: "[o.g]", "lable")
  }

  func testRejectsABindingThatIsNotATable() {
    assertDecodeError(
      """
      [o]
      s = "/Applications/Safari.app"
      """,
      names: "[o.s]", "must be a table")
  }

  func testRejectsAnActionWithBindings() {
    assertDecodeError(
      """
      [o.g]
      app = "/Applications/Ghostty.app"
      h = { url = "https://ghostty.org" }
      """,
      names: "[o.g]", "binding h")
  }

  func testRejectsAFieldThatIsNotAString() {
    assertDecodeError(
      """
      [o]
      "," = { app = "/Applications/Safari.app", label = 3 }
      """,
      names: #"[o.","]"#, "label must be a string")
  }

  func testReportsDuplicateKeysWithTheirLine() {
    assertDecodeError(
      """
      a = { app = "/Applications/A.app" }
      a = { app = "/Applications/B.app" }
      """,
      names: "Line 2")
  }

  // MARK: - Helpers

  private func assertDecodeError(
    _ toml: String, names expected: String...,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertThrowsError(try TOMLConfig.decode(toml), file: file, line: line) { error in
      let description = "\(error)"
      for part in expected {
        XCTAssertTrue(
          description.contains(part), "\"\(description)\" does not name \(part)",
          file: file, line: line)
      }
    }
  }

  private func keys(_ group: Group) -> [String] {
    group.actions.map { $0.item.key ?? "" }
  }

  private func subgroup(_ key: String, of group: Group) -> Group? {
    for case .group(let child) in group.actions where child.key == key { return child }
    return nil
  }

  /// Every shape the TOML layout has to carry: punctuation keys that need quoting, a case pair,
  /// all four action types, three menu levels, a binding after a subgroup, an empty group,
  /// labels and icons on both kinds, values that need each kind of quoting, a non-ASCII label,
  /// special key names and a glyph key.
  private let fixture = #"""
    {
      "type": "group",
      "actions": [
        { "key": "t", "type": "application", "value": "/System/Applications/Utilities/Terminal.app" },
        { "key": ",", "type": "application", "value": "/System/Applications/System Settings.app", "label": "Settings" },
        { "key": "[", "type": "url", "value": "https://example.com/search?q=\"leader key\"", "label": "Search" },
        { "key": "'", "type": "command", "value": "echo 'single quoted'", "iconPath": "terminal" },
        { "key": "`", "type": "command", "value": "printf \"%s\\n\" 'both' C:\\temp", "label": "Both quotes" },
        { "key": "space", "type": "folder", "value": "~/Downloads", "label": "Downloads" },
        {
          "key": "o",
          "type": "group",
          "label": "Open",
          "iconPath": "folder.fill",
          "actions": [
            { "key": "C", "type": "application", "value": "/System/Applications/Calendar.app", "iconPath": "calendar" },
            {
              "key": "c",
              "type": "group",
              "label": "Chat",
              "actions": [
                { "key": "m", "type": "application", "value": "/System/Applications/Messages.app" },
                {
                  "key": "d",
                  "type": "group",
                  "iconPath": "sparkles",
                  "actions": [
                    { "key": "enter", "type": "url", "value": "https://example.org/", "label": "Café ☕" }
                  ]
                }
              ]
            },
            { "key": "d", "type": "application", "value": "/System/Applications/Dictionary.app" },
            { "key": "e", "type": "group", "actions": [] },
            { "key": "left", "type": "url", "value": "https://left.example/" },
            { "key": "␣", "type": "command", "value": "say hello" }
          ]
        },
        { "key": "z", "type": "url", "value": "https://z.example/", "label": "Zed" }
      ]
    }
    """#
}
