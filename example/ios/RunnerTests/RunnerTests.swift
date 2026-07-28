import Flutter
import UIKit
import XCTest

@testable import xue_hua_device_info

class RunnerTests: XCTestCase {
  func testGetDeviceInfo() {
    let plugin = XueHuaDeviceInfoPlugin()
    let call = FlutterMethodCall(methodName: "getDeviceInfo", arguments: nil)
    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      let map = result as? [String: Any?]
      XCTAssertNotNil(map)
      XCTAssertEqual(map?["manufacturer"] as? String, "Apple")
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
