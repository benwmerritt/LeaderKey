import Foundation
import TOMLDecoder

/// The optional `config.toml`. Each menu is a table keyed by the key you press. A binding with
/// one of `app`, `url`, `cmd` or `folder` is an action; a table with none of them is a group,
/// whose other keys are its bindings. File order is menu order.
enum TOMLConfig {
  /// Each action type's field, in the order the error messages list them.
  private static let actionFields: [(name: String, type: Type)] = [
    ("app", .application), ("url", .url), ("cmd", .command), ("folder", .folder),
  ]
  private static let metadataFields: Set<String> = ["label", "icon"]

  // MARK: - Decoding

  static func decode(_ text: String) throws -> Group {
    let table: TOMLTable
    do {
      table = try TOMLTable(source: text)
    } catch {
      throw TOMLConfigError.syntax(error)
    }
    return try group(table, key: nil, path: [])
  }

  private static func group(_ table: TOMLTable, key: String?, path: [String]) throws -> Group {
    var actions: [ActionOrGroup] = []
    for childKey in table.keys where !metadataFields.contains(childKey) {
      let childPath = path + [childKey]
      guard let child = try? table.table(forKey: childKey) else {
        throw TOMLConfigError.binding(
          path: childPath,
          problem:
            "is not a binding. In a menu every key other than label and icon is a binding, "
            + "a table with one of app, url, cmd or folder, such as "
            + "\(tomlKey(childKey)) = { app = \"/Applications/Safari.app\" }.")
      }
      actions.append(try binding(child, key: childKey, path: childPath))
    }
    return Group(
      key: key,
      label: try optionalString("label", in: table, at: path),
      iconPath: try optionalString("icon", in: table, at: path),
      actions: actions)
  }

  private static func binding(_ table: TOMLTable, key: String, path: [String]) throws
    -> ActionOrGroup
  {
    let present = actionFields.filter { table.contains(key: $0.name) }
    guard let action = present.first else {
      return .group(try group(table, key: key, path: path))
    }
    guard present.count == 1 else {
      throw TOMLConfigError.binding(
        path: path,
        problem: "has both \(present.map(\.name).joined(separator: " and ")). "
          + "A binding takes exactly one of app, url, cmd and folder.")
    }
    if let extra = table.keys.first(where: { $0 != action.name && !metadataFields.contains($0) }) {
      let isBinding = (try? table.table(forKey: extra)) != nil
      throw TOMLConfigError.binding(
        path: path,
        problem: isBinding
          ? "has \(action.name) and also holds the binding \(tomlKey(extra)). "
            + "A binding is an action or a group, not both."
          : "has an unknown field \(tomlKey(extra)). "
            + "A binding's fields are app, url, cmd, folder, label and icon.")
    }
    return .action(
      Action(
        key: key, type: action.type,
        label: try optionalString("label", in: table, at: path),
        value: try string(action.name, in: table, at: path),
        iconPath: try optionalString("icon", in: table, at: path)))
  }

  private static func string(_ field: String, in table: TOMLTable, at path: [String]) throws
    -> String
  {
    do {
      return try table.string(forKey: field)
    } catch {
      throw TOMLConfigError.binding(path: path, problem: "\(field) must be a string.")
    }
  }

  private static func optionalString(_ field: String, in table: TOMLTable, at path: [String])
    throws -> String?
  {
    table.contains(key: field) ? try string(field, in: table, at: path) : nil
  }

  // MARK: - Encoding

  /// The config as menu sections. A group's bindings before its first subgroup are one-line
  /// inline tables; since TOML puts a table's own keys before its sub-tables, every binding from
  /// the first subgroup on gets its own section, which keeps file order equal to menu order.
  static func encode(_ root: Group) -> String {
    var lines = fields(of: .group(root)).map { "\($0.name) = \($0.value)" }
    appendMenu(root, at: [], to: &lines)
    return lines.drop(while: \.isEmpty).joined(separator: "\n") + "\n"
  }

  private static func appendMenu(_ group: Group, at path: [String], to lines: inout [String]) {
    let firstGroup =
      group.actions.firstIndex {
        if case .group = $0 { return true } else { return false }
      } ?? group.actions.endIndex

    let inline = group.actions[..<firstGroup]
    let width = inline.map { tomlKey(keyText($0.item)).count }.max() ?? 0
    for child in inline {
      let key = tomlKey(keyText(child.item))
      let padding = String(repeating: " ", count: width - key.count)
      let pairs = fields(of: child).map { "\($0.name) = \($0.value)" }
      lines.append("\(key)\(padding) = { \(pairs.joined(separator: ", ")) }")
    }

    for child in group.actions[firstGroup...] {
      let childPath = path + [keyText(child.item)]
      lines.append("")
      lines.append(section(childPath))
      lines += fields(of: child).map { "\($0.name) = \($0.value)" }
      if case .group(let subgroup) = child {
        appendMenu(subgroup, at: childPath, to: &lines)
      }
    }
  }

  /// A binding's own fields with their values written as TOML: the action type first, then
  /// `label` and `icon` whenever they are set, even to an empty string.
  private static func fields(of item: ActionOrGroup) -> [(name: String, value: String)] {
    var fields: [(name: String, value: String)] = []
    if case .action(let action) = item,
      let field = actionFields.first(where: { $0.type == action.type })
    {
      fields.append((field.name, tomlString(action.value)))
    }
    if let label = item.item.label { fields.append(("label", tomlString(label))) }
    if let icon = item.item.iconPath { fields.append(("icon", tomlString(icon))) }
    return fields
  }

  /// The key as the JSON config stores it, so a glyph such as `␣` becomes `space`.
  private static func keyText(_ item: Item) -> String {
    guard let key = item.key else { return "" }
    return KeyMaps.text(for: key) ?? key
  }

  // MARK: - TOML syntax

  /// A table header such as `[o.","]`, quoting keys that are not bare.
  static func section(_ path: [String]) -> String {
    "[\(path.map(tomlKey).joined(separator: "."))]"
  }

  private static let bareKeyCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

  private static func tomlKey(_ key: String) -> String {
    let isBare = !key.isEmpty && key.unicodeScalars.allSatisfy(bareKeyCharacters.contains)
    return isBare ? key : basicString(key)
  }

  /// A literal string where that avoids escaping, otherwise a basic string.
  private static func tomlString(_ value: String) -> String {
    let needsEscaping = value.contains { $0 == "\"" || $0 == "\\" }
    let fitsLiteral = !value.contains("'") && !value.unicodeScalars.contains(where: isControl)
    return needsEscaping && fitsLiteral ? "'\(value)'" : basicString(value)
  }

  private static func basicString(_ value: String) -> String {
    var escaped = ""
    for scalar in value.unicodeScalars {
      switch scalar {
      case "\"": escaped += "\\\""
      case "\\": escaped += "\\\\"
      case "\u{08}": escaped += "\\b"
      case "\t": escaped += "\\t"
      case "\n": escaped += "\\n"
      case "\u{0C}": escaped += "\\f"
      case "\r": escaped += "\\r"
      case _ where isControl(scalar):
        escaped += String(format: "\\u%04X", scalar.value)
      default: escaped.unicodeScalars.append(scalar)
      }
    }
    return "\"\(escaped)\""
  }

  private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
    scalar.value < 0x20 || scalar.value == 0x7F
  }
}

enum TOMLConfigError: Error, CustomStringConvertible {
  /// The text is not valid TOML. TOMLDecoder's message carries the line number.
  case syntax(Error)
  /// A binding the TOML parses fine but Leader Key cannot read, at its section path.
  case binding(path: [String], problem: String)

  var description: String {
    switch self {
    case .syntax(let error):
      return "config.toml: \(error)"
    case .binding(let path, let problem):
      let place = path.isEmpty ? "The top level" : TOMLConfig.section(path)
      return "config.toml: \(place) \(problem)"
    }
  }
}

extension Group {
  /// Whether `other` holds the same config, compared as the JSON config stores it. `==` also
  /// compares actions' UI-only identities, which every load makes afresh.
  func hasSameConfig(as other: Group) -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    guard let mine = try? encoder.encode(self), let theirs = try? encoder.encode(other) else {
      return false
    }
    return mine == theirs
  }
}
