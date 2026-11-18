import XCTest
@testable import Soundly

final class FoundationTests: XCTestCase {
    func testAppearanceChoicesAreStableAndDistinct() {
        let themes = SoundlyTheme.allCases
        XCTAssertEqual(Set(themes.map(\.rawValue)).count, themes.count)
        for previous in ["system", "light", "dark", "oled", "ocean", "sunset", "amethyst", "forest", "rose", "graphite", "ivory", "midnight"] {
            XCTAssertNotNil(SoundlyTheme(rawValue: previous))
        }
        for theme in [SoundlyTheme.porcelain, .mist, .linen, .matcha, .lavender, .petal] {
            XCTAssertEqual(theme.scheme, .light, theme.rawValue)
        }
        XCTAssertNil(SoundlyTheme.system.scheme)
        XCTAssertEqual(SoundlyTheme.oled.scheme, .dark)
    }
}
