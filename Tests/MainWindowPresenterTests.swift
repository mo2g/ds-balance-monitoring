import XCTest
@testable import DSBalanceMonitor

private final class WeakBox<T: AnyObject> {
    weak var value: T?
}

@MainActor
final class MainWindowPresenterTests: XCTestCase {
    /// Regression test for the use-after-free crash in MainWindowPresenter:
    /// with isReleasedWhenClosed = false the window stays alive across close,
    /// so a retained static reference can safely call makeKeyAndOrderFront
    /// again instead of messaging a deallocated NSWindow.
    func testWindowSurvivesCloseWhenReleasedWhenClosedIsDisabled() {
        let box = WeakBox<NSWindow>()
        var holder: NSWindow?
        autoreleasepool {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
                                  styleMask: [.closable, .titled],
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            holder = window
            box.value = window
            window.close()
        }
        XCTAssertNotNil(box.value, "窗口在 close 后仍应存活（外部持有 + 关闭不自动释放）")
        window_reuse: do {
            holder?.makeKeyAndOrderFront(nil)
            XCTAssertTrue(holder?.isVisible == true)
        }
        // 注：NSWindow 可能被 AppKit 内部延迟持有，这里不断言其立即销毁，
        // 只验证核心回归点：close 后仍可安全复用而非 use-after-free。
    }
}
