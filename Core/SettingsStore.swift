import Foundation
import Combine

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case iconAndValue, iconOnly, valueOnly
    public var id: String { rawValue }
    public func title(language: ResolvedLanguage) -> String {
        Localization.string("menuBarMode.\(rawValue)", language: language)
    }
}

public final class SettingsStore: ObservableObject {
    @Published public var threshold: Double {
        didSet { defaults.set(threshold, forKey: "alertThreshold") }
    }
    @Published public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published public var menuBarMode: MenuBarDisplayMode {
        didSet { defaults.set(menuBarMode.rawValue, forKey: "menuBarMode") }
    }
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published public var preferredCurrency: String {
        didSet { defaults.set(preferredCurrency, forKey: "preferredCurrency") }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: "alertThreshold") == nil { defaults.set(5.0, forKey: "alertThreshold") }
        threshold = defaults.object(forKey: "alertThreshold") as? Double ?? 5.0
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        menuBarMode = MenuBarDisplayMode(rawValue: defaults.string(forKey: "menuBarMode") ?? "") ?? .iconAndValue
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        preferredCurrency = defaults.string(forKey: "preferredCurrency") ?? "CNY"
    }
}
