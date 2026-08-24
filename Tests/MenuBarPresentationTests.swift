import XCTest
@testable import DSBalanceMonitor

final class MenuBarPresentationTests: XCTestCase {
    func testIconAndValueShowsBoth() {
        let p = MenuBarPresentation.make(statusText: "¥4.83", mode: .iconAndValue)
        XCTAssertTrue(p.showsIcon)
        XCTAssertEqual(p.title, " ¥4.83")
    }

    func testIconOnlyHidesTitleUnlessWarning() {
        XCTAssertEqual(MenuBarPresentation.make(statusText: "¥4.83", mode: .iconOnly).title, "")
        XCTAssertEqual(MenuBarPresentation.make(statusText: "⚠️", mode: .iconOnly).title, "⚠️")
    }

    func testValueOnlyHidesIcon() {
        let p = MenuBarPresentation.make(statusText: "¥4.83", mode: .valueOnly)
        XCTAssertFalse(p.showsIcon)
        XCTAssertEqual(p.title, "¥4.83")
    }
}
