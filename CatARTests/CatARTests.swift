
import XCTest
@testable import CatAR
import SwiftUI

final class CatARTests: XCTestCase {
  func testCoordinatorInitialization() {
    let isPlacing = Binding.constant(true)
    let statusMessage = Binding.constant("Status")
    let coordinator = ARViewContainer.Coordinator()
    coordinator.isPlacing = isPlacing
    coordinator.statusMessage = statusMessage
    XCTAssertNotNil(coordinator.isPlacing)
    XCTAssertNotNil(coordinator.statusMessage)
  }
}
