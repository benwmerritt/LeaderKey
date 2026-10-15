import XCTest

@testable import Leader_Key

final class CenteredOriginTests: XCTestCase {
  func testCentersPanelInVisibleFrame() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 870)

    let origin = visibleFrame.centeredOrigin(for: NSSize(width: 580, height: 693))

    XCTAssertEqual(origin, NSPoint(x: 430, y: 88.5))
  }

  func testCentersOnScreenLeftOfPrimaryAboveDock() {
    let visibleFrame = NSRect(x: -1920, y: 70, width: 1920, height: 1010)

    let origin = visibleFrame.centeredOrigin(for: NSSize(width: 580, height: 56))

    XCTAssertEqual(origin, NSPoint(x: -1250, y: 547))
  }
}
