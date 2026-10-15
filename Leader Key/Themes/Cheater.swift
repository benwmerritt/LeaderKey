import Foundation
import SwiftUI

enum Cheater {
  class Window: MainWindow {
    override var hasCheatsheet: Bool { return false }
    private var shownOn: NSScreen?

    required init(controller: Controller) {
      super.init(controller: controller, contentRect: NSRect(x: 0, y: 0, width: 0, height: 0))
      let view = Cheatsheet.CheatsheetView()
      contentView = NSHostingView(rootView: view.environmentObject(self.controller.userState))
    }

    override func show(on screen: NSScreen, after: (() -> Void)?) {
      shownOn = screen
      centerOnScreen()

      makeKeyAndOrderFront(nil)

      fadeInAndUp {
        after?()
      }
    }

    override func hide(after: (() -> Void)?) {
      fadeOutAndDown {
        self.close()
        after?()
      }
    }

    override func notFound() {
      shake()
    }

    /// The hosting view resizes the panel to fit each group, and AppKit keeps the top edge in
    /// place when it does, so a taller group would run off the bottom of the screen.
    @objc func windowDidResize(_ notification: Notification) {
      centerOnScreen()
    }

    private func centerOnScreen() {
      guard let screen = shownOn else { return }
      setFrameOrigin(screen.visibleFrame.centeredOrigin(for: frame.size))
    }
  }
}
