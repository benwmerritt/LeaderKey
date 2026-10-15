import AppKit
import Foundation

func delay(_ milliseconds: Int, callback: @escaping () -> Void) {
  DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: callback)
}

extension NSRect {
  func centeredOrigin(for size: NSSize) -> NSPoint {
    return NSPoint(x: midX - size.width / 2, y: midY - size.height / 2)
  }
}
