import Foundation

public struct MenuBarPresentation: Equatable {
    public var showsIcon: Bool
    public var title: String

    public static func make(statusText: String, mode: MenuBarDisplayMode) -> MenuBarPresentation {
        switch mode {
        case .iconAndValue:
            return MenuBarPresentation(showsIcon: true, title: " \(statusText)")
        case .iconOnly:
            return MenuBarPresentation(showsIcon: true, title: statusText == "⚠️" ? "⚠️" : "")
        case .valueOnly:
            return MenuBarPresentation(showsIcon: false, title: statusText)
        }
    }
}
