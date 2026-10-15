import Foundation

/// A placeholder in a URL action's value, filled in each time the action runs.
enum URLPlaceholder: Hashable {
  /// `{clipboard}`: the clipboard's text.
  case clipboard
  /// `{argument}`, `{argument name="X"}`, `{query}` or `{search query}`: text typed into a box
  /// labelled `label`.
  case text(label: String)
}

enum URLTemplate {
  private struct Cancelled: Error {}

  private static let placeholderPattern =
    #/\{(?:clipboard|argument name="(?<name>[^"]+)"|(?<keyword>argument|query|search query))\}/#
    .ignoresCase()

  private static let unreserved = Set(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)

  /// Replaces each placeholder in `template` with its value from `fill`, percent-encoded. `fill`
  /// is asked once per distinct placeholder, in order of first appearance; any other `{...}`
  /// stays as written. Returns nil as soon as `fill` does.
  static func expand(_ template: String, fill: (URLPlaceholder) -> String?) -> String? {
    var values: [URLPlaceholder: String] = [:]
    return try? template.replacing(placeholderPattern) { match -> String in
      let placeholder: URLPlaceholder
      if let name = match.output.name {
        placeholder = .text(label: String(name))
      } else if let keyword = match.output.keyword {
        placeholder = .text(label: keyword.capitalized)
      } else {
        placeholder = .clipboard
      }

      if let value = values[placeholder] { return value }
      guard let value = fill(placeholder) else { throw Cancelled() }
      let encoded = percentEncoded(value)
      values[placeholder] = encoded
      return encoded
    }
  }

  /// Encodes every byte outside RFC 3986's unreserved set, so a value cannot end the query,
  /// path segment or fragment it lands in.
  private static func percentEncoded(_ value: String) -> String {
    value.utf8.map { byte in
      unreserved.contains(byte)
        ? String(Character(Unicode.Scalar(byte))) : String(format: "%%%02X", byte)
    }.joined()
  }
}
