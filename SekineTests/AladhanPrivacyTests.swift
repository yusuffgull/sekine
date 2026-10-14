import XCTest
@testable import Sekine

final class AladhanPrivacyTests: XCTestCase {
    func testCoordinatesAreSentRoundedToTwoDecimals() {
        XCTAssertEqual(AladhanProvider.coarse(41.008238), "41.01")
        XCTAssertEqual(AladhanProvider.coarse(28.978359), "28.98")
        XCTAssertEqual(AladhanProvider.coarse(-33.86882), "-33.87")
    }
}
