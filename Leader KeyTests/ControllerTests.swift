import XCTest

@testable import Leader_Key

final class ControllerTests: XCTestCase {
  func testHasItsPanelWindowAsSoonAsItIsMade() {
    let userConfig = UserConfig()
    let controller = Controller(
      userState: UserState(userConfig: userConfig), userConfig: userConfig)

    XCTAssertNotNil(controller.window)
  }
}
