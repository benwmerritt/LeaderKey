// Prints each on-screen Leader Key window against the visible frame of the screen it sits on.
// Usage: measure-panel [label]   one line per window
//        measure-panel --ids     window numbers only, for screencapture -l
//        measure-panel --made    window numbers of every Leader Key window, shown or not
import AppKit
import CoreGraphics

let argument = CommandLine.arguments.dropFirst().first ?? "-"
let primaryHeight = NSScreen.screens[0].frame.height
let options: CGWindowListOption =
  argument == "--made" ? .optionAll : [.optionOnScreenOnly, .excludeDesktopElements]
let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
let windows = infos.filter { ($0[kCGWindowOwnerName as String] as? String) == "Leader Key" }

if argument == "--ids" || argument == "--made" {
  for info in windows {
    if let number = info[kCGWindowNumber as String] as? Int { print(number) }
  }
  exit(0)
}

if windows.isEmpty { print("\(argument): no on-screen Leader Key window") }

func f(_ v: CGFloat) -> String { String(format: "%.1f", v) }

for info in windows {
  guard let b = info[kCGWindowBounds as String] as? [String: CGFloat],
    let x = b["X"], let topY = b["Y"], let w = b["Width"], let h = b["Height"]
  else { continue }
  let rect = NSRect(x: x, y: primaryHeight - topY - h, width: w, height: h)
  let screen =
    NSScreen.screens.first { $0.frame.contains(NSPoint(x: rect.midX, y: rect.midY)) }
    ?? NSScreen.screens[0]
  let v = screen.visibleFrame
  let number = info[kCGWindowNumber as String] as? Int ?? -1
  let alpha = info[kCGWindowAlpha as String] as? CGFloat ?? -1
  print(
    "\(argument): window #\(number) \(f(w))x\(f(h)) alpha=\(f(alpha))"
      + " left=\(f(rect.minX)) right=\(f(rect.maxX)) top=\(f(rect.maxY)) bottom=\(f(rect.minY))"
      + " midX=\(f(rect.midX)) midY=\(f(rect.midY))"
      + " | visible right=\(f(v.maxX)) top=\(f(v.maxY)) bottom=\(f(v.minY))"
      + " midX=\(f(v.midX)) midY=\(f(v.midY))"
      + " | midX-offset=\(f(rect.midX - v.midX)) midY-offset=\(f(rect.midY - v.midY))"
      + " past-bottom=\(f(max(0, v.minY - rect.minY))) past-top=\(f(max(0, rect.maxY - v.maxY)))"
  )
}
