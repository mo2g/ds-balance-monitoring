import Foundation
import Combine

final class AppServices {
    static let shared = AppServices()
    let repository: BalanceRepository
    let settings: SettingsStore
    let state: AppState
    let secretStore: SecretStore
    let language: LanguageManager
    /// Fired when the user saves settings (e.g. API key) and wants an
    /// immediate balance refresh instead of waiting for the next minute.
    let pollRequests = PassthroughSubject<Void, Never>()
    /// Fired with the current date every time a poll successfully writes new
    /// samples, so the chart window can refresh its tail in place.
    let samplesDidChange = PassthroughSubject<Date, Never>()

    init() {
        let settings = SettingsStore()
        self.settings = settings
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DSBalanceMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        repository = (try? BalanceRepository.open(at: dir.appendingPathComponent("balances.sqlite")))
            ?? (try! BalanceRepository.inMemory())
        state = AppState(preferredCurrency: { settings.preferredCurrency })
        secretStore = UserDefaultsSecretStore()
        language = LanguageManager.shared
    }
}
