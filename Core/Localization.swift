import Foundation
import Combine

/// The language preference chosen in Settings.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Follow the system language (Chinese UI for zh-*, English otherwise).
    case system
    case zhHans = "zh-Hans"
    case en

    public var id: String { rawValue }
}

/// The concrete language used to look strings up (never `.system`).
public enum ResolvedLanguage: String, CaseIterable, Sendable {
    case zhHans = "zh-Hans"
    case en
}

/// Holds the user's language preference, persists it in UserDefaults and
/// resolves the effective language. Views observe it through
/// `.environmentObject` so switching the language re-renders the whole UI.
public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    private static let preferenceKey = "appLanguage"

    @Published public var preference: AppLanguage {
        didSet { defaults.set(preference.rawValue, forKey: Self.preferenceKey) }
    }

    private let defaults: UserDefaults
    private let systemLanguages: () -> [String]

    public init(defaults: UserDefaults = .standard,
                systemLanguages: @escaping () -> [String] = { Locale.preferredLanguages }) {
        self.defaults = defaults
        self.systemLanguages = systemLanguages
        if let raw = defaults.string(forKey: Self.preferenceKey),
           let stored = AppLanguage(rawValue: raw) {
            self.preference = stored
        } else {
            self.preference = .system
        }
    }

    public var resolved: ResolvedLanguage {
        switch preference {
        case .zhHans: return .zhHans
        case .en: return .en
        case .system:
            let first = systemLanguages().first ?? ""
            return first.lowercased().hasPrefix("zh") ? .zhHans : .en
        }
    }

    public func t(_ key: String) -> String {
        Localization.string(key, language: resolved)
    }
}

/// Pure string tables. Keyed by semantic identifier so tests and Core types
/// can resolve text without touching UI state.
public enum Localization {
    public static func string(_ key: String, language: ResolvedLanguage) -> String {
        let table = Self.tables[language] ?? Self.tables[.zhHans] ?? [:]
        return table[key] ?? key
    }

    public static func localized(error: BalanceAPIError, language: ResolvedLanguage) -> String {
        switch error {
        case .missingAPIKey:
            return string("error.missingAPIKey", language: language)
        case .invalidResponse:
            return string("error.invalidResponse", language: language)
        case .httpStatus(let code):
            if code == 401 { return string("error.http401", language: language) }
            return String(format: string("error.httpStatus", language: language), String(code))
        case .decoding(let message):
            return String(format: string("error.decoding", language: language), message)
        case .network(let message):
            return String(format: string("error.network", language: language), message)
        }
    }

    private static let tables: [ResolvedLanguage: [String: String]] = [
        .zhHans: [
            // granularity / metric
            "granularity.minute": "分",
            "granularity.hour": "时",
            "granularity.day": "天",
            "granularity.month": "月",
            "metric.balance": "余额曲线",
            "metric.consumed": "消耗量",

            // errors
            "error.missingAPIKey": "未配置 API Key",
            "error.invalidResponse": "服务器响应无效",
            "error.http401": "API Key 无效（401）",
            "error.httpStatus": "请求失败（HTTP %@）",
            "error.decoding": "响应解析失败：%@",
            "error.network": "网络错误：%@",

            // common
            "app.title": "DeepSeek 余额",
            "window.title": "DeepSeek 余额监控",
            "common.openWindow": "打开完整窗口",
            "common.settings": "设置",
            "common.quit": "退出",
            "menu.quitApp": "退出 DS Balance Monitor",

            // settings
            "settings.account": "账户",
            "settings.apiKeyPlaceholder": "DeepSeek API Key（sk-...）",
            "settings.saveKey": "保存 API Key",
            "settings.saved": "已保存",
            "settings.savedRefreshing": "已保存，正在刷新…",
            "settings.cleared": "已清除",
            "settings.saveFailed": "保存失败：%@",
            "settings.keyLocalNote": "密钥只保存在本机（偏好设置，明文存储），保存后立即重新获取余额。",
            "settings.notConfigured": "尚未配置",
            "settings.configured": "已配置 %@…%@",
            "settings.alerts": "余额告警",
            "settings.enableAlerts": "启用低余额通知",
            "settings.threshold": "阈值：%@",
            "settings.menuBar": "菜单栏",
            "settings.displayMode": "显示模式",
            "settings.preferredCurrency": "优先币种",
            "settings.system": "系统",
            "settings.launchAtLogin": "开机自启",
            "settings.language": "语言",

            // menu bar display modes
            "menuBarMode.iconAndValue": "图标 + 数字",
            "menuBarMode.iconOnly": "仅图标",
            "menuBarMode.valueOnly": "仅数字",

            // language options
            "language.option.system": "跟随系统",
            "language.option.zh-Hans": "中文",
            "language.option.en": "English",

            // chart
            "chart.year": "年份",
            "chart.currency": "币种",
            "chart.allCurrencies": "全部",
            "chart.granularity": "粒度",
            "chart.metric": "口径",
            "chart.loadedNodes": "已加载 %d 个节点",
            "chart.loadedRangeConsumed": "已加载区间消耗：%@",
            "chart.emptyYear": "该年份暂无数据",
            "chart.loadingEarlier": "正在加载更早数据…",
            "chart.scrollHint": "向左滚动可加载更早数据",
            "chart.earliestReached": "已到该年份最早数据",
            "chart.loadOlder": "加载更早",
            "chart.backToLatest": "回到最新",
            "chart.newDataBackToLatest": "有新数据 · 回到最新",
            "chart.hoverHint": "将鼠标移到图表上，可查看每个节点的余额与消耗明细。",
            "chart.includesRecharge": "含充值",
            "chart.startBalance": "起始余额",
            "chart.endBalance": "结束余额",
            "chart.consumedInPeriod": "本时段消耗",
            "chart.note": "说明",
            "chart.rechargeNote": "余额上升，充值点消耗已剔除",
            "chart.axisConsumption": "消耗",
            "chart.axisBalance": "余额",
            "chart.loadOlderFailed": "加载更早数据失败：%@",
            "chart.refreshFailed": "刷新最新数据失败：%@",

            // notification
            "notification.lowBalanceTitle": "DeepSeek 余额不足",
            "notification.lowBalanceBody": "%@ 余额仅剩 %@，低于阈值 %@，请及时充值。",
        ],
        .en: [
            "granularity.minute": "Minute",
            "granularity.hour": "Hour",
            "granularity.day": "Day",
            "granularity.month": "Month",
            "metric.balance": "Balance",
            "metric.consumed": "Consumption",

            "error.missingAPIKey": "API key is not configured",
            "error.invalidResponse": "Invalid server response",
            "error.http401": "Invalid API key (401)",
            "error.httpStatus": "Request failed (HTTP %@)",
            "error.decoding": "Failed to decode response: %@",
            "error.network": "Network error: %@",

            "app.title": "DeepSeek Balance",
            "window.title": "DeepSeek Balance Monitor",
            "common.openWindow": "Open Full Window",
            "common.settings": "Settings",
            "common.quit": "Quit",
            "menu.quitApp": "Quit DS Balance Monitor",

            "settings.account": "Account",
            "settings.apiKeyPlaceholder": "DeepSeek API Key (sk-...)",
            "settings.saveKey": "Save API Key",
            "settings.saved": "Saved",
            "settings.savedRefreshing": "Saved, refreshing…",
            "settings.cleared": "Cleared",
            "settings.saveFailed": "Save failed: %@",
            "settings.keyLocalNote": "The key is stored only on this Mac (plaintext in preferences). Saving refreshes the balance immediately.",
            "settings.notConfigured": "Not configured",
            "settings.configured": "Configured: %@…%@",
            "settings.alerts": "Balance Alerts",
            "settings.enableAlerts": "Enable low-balance notifications",
            "settings.threshold": "Threshold: %@",
            "settings.menuBar": "Menu Bar",
            "settings.displayMode": "Display Mode",
            "settings.preferredCurrency": "Preferred Currency",
            "settings.system": "System",
            "settings.launchAtLogin": "Launch at Login",
            "settings.language": "Language",

            "menuBarMode.iconAndValue": "Icon + Value",
            "menuBarMode.iconOnly": "Icon Only",
            "menuBarMode.valueOnly": "Value Only",

            "language.option.system": "Follow System",
            "language.option.zh-Hans": "中文",
            "language.option.en": "English",

            "chart.year": "Year",
            "chart.currency": "Currency",
            "chart.allCurrencies": "All",
            "chart.granularity": "Granularity",
            "chart.metric": "Metric",
            "chart.loadedNodes": "%d points loaded",
            "chart.loadedRangeConsumed": "Loaded range consumption: %@",
            "chart.emptyYear": "No data for this year",
            "chart.loadingEarlier": "Loading earlier data…",
            "chart.scrollHint": "Scroll left to load earlier data",
            "chart.earliestReached": "Reached the earliest data of this year",
            "chart.loadOlder": "Load Earlier",
            "chart.backToLatest": "Back to Latest",
            "chart.newDataBackToLatest": "New data · Back to Latest",
            "chart.hoverHint": "Hover over the chart to inspect each point's balance and consumption.",
            "chart.includesRecharge": "Includes Recharge",
            "chart.startBalance": "Start Balance",
            "chart.endBalance": "End Balance",
            "chart.consumedInPeriod": "Consumption",
            "chart.note": "Note",
            "chart.rechargeNote": "Balance rose; the recharge point is excluded from consumption",
            "chart.axisConsumption": "Consumption",
            "chart.axisBalance": "Balance",
            "chart.loadOlderFailed": "Failed to load earlier data: %@",
            "chart.refreshFailed": "Failed to refresh latest data: %@",

            "notification.lowBalanceTitle": "DeepSeek Balance Low",
            "notification.lowBalanceBody": "%@ balance is down to %@, below the %@ threshold. Please top up.",
        ],
    ]
}
