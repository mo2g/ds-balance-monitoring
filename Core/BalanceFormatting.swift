import Foundation

public enum BalanceFormatting {
    public static let apiKeyAccount = "deepseek_api_key"

    public static func statusText(balances: [BalanceInfo], preferredCurrency: String) -> String {
        guard let target = balances.first(where: { $0.currency == preferredCurrency }) ?? balances.first else {
            return "—"
        }
        return "\(currencySymbol(for: target.currency))\(formattedAmount(target.totalBalance))"
    }

    public static func currencySymbol(for code: String) -> String {
        switch code.uppercased() {
        case "CNY", "RMB": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return code + " "
        }
    }

    public static func formattedAmount(_ value: Double, fractionDigits: Int = 2) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}
