import Cocoa

/// Asks for a line of text. macOS ignores a menu-bar app's request to come to the front, so this
/// is a non-activating panel like the main window: it takes keyboard focus while another app
/// stays active. Like the main window, it goes away when it loses focus, which cancels it.
final class TextPrompt: NSPanel, NSWindowDelegate {
  private let field = NSTextField()

  /// Nil when the user cancels.
  static func ask(title: String, label: String, message: String = "") -> String? {
    let prompt = TextPrompt(title: title, label: label, message: message)
    prompt.center()
    prompt.makeKeyAndOrderFront(nil)
    let response = NSApp.runModal(for: prompt)
    prompt.orderOut(nil)
    return response == .OK ? prompt.field.stringValue : nil
  }

  private init(title: String, label: String, message: String) {
    super.init(
      contentRect: .zero, styleMask: [.titled, .nonactivatingPanel], backing: .buffered,
      defer: false)
    self.title = title
    delegate = self
    level = .modalPanel
    hidesOnDeactivate = false
    isReleasedWhenClosed = false

    field.placeholderString = label
    field.widthAnchor.constraint(equalToConstant: 300).isActive = true

    let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(pressCancel(_:)))
    cancelButton.keyEquivalent = "\u{1b}"
    let openButton = NSButton(title: "Open", target: self, action: #selector(pressOpen(_:)))
    openButton.keyEquivalent = "\r"
    let buttons = NSStackView()
    buttons.setViews([cancelButton, openButton], in: .trailing)

    var rows: [NSView] = [field, buttons]
    if !message.isEmpty {
      let messageLabel = NSTextField(wrappingLabelWithString: message)
      messageLabel.preferredMaxLayoutWidth = 300
      rows.insert(messageLabel, at: 0)
    }
    let stack = NSStackView(views: rows)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
    buttons.widthAnchor.constraint(equalTo: field.widthAnchor).isActive = true

    contentView = stack
    setContentSize(stack.fittingSize)
    initialFirstResponder = field
  }

  @objc private func pressOpen(_ sender: Any?) {
    NSApp.stopModal(withCode: .OK)
  }

  @objc private func pressCancel(_ sender: Any?) {
    NSApp.stopModal(withCode: .cancel)
  }

  func windowDidResignKey(_ notification: Notification) {
    if NSApp.modalWindow === self { NSApp.stopModal(withCode: .cancel) }
  }
}
