import Foundation
import UserNotifications

final class SystemAlertNotifier: AlertNotifying {
    func notify(_ decision: AlertDecision) {
        let content = UNMutableNotificationContent()
        let language = AppServices.shared.language
        content.title = language.t("notification.lowBalanceTitle")
        let amount = BalanceFormatting.formattedAmount(decision.totalBalance)
        content.body = String(format: language.t("notification.lowBalanceBody"),
                              decision.currency, amount,
                              BalanceFormatting.formattedAmount(decision.threshold))
        content.sound = .default
        let request = UNNotificationRequest(identifier: "low-balance-\(decision.currency)-\(Date().timeIntervalSince1970)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
