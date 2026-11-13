import XCTest
@testable import Soundly

final class FoundationTests: XCTestCase {
    func testAppearanceChoicesAreStableAndDistinct() {
        XCTAssertEqual(Set(SoundlyTheme.allCases.map(\.rawValue)).count, 12)
        XCTAssertNil(SoundlyTheme.system.scheme)
        XCTAssertEqual(SoundlyTheme.oled.scheme, .dark)
    }
}
