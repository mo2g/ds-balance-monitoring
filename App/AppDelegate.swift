import AppKit
import Combine
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var loopTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private var pollRequestsCancellable: AnyCancellable?
    private var languageCancellable: AnyCancellable?
    private let secretStore: SecretStore = AppServices.shared.secretStore
    private var alertEngine: AlertEngine?
    private var consecutiveFailures = 0

    private lazy var scheduler = PollingScheduler(
        provider: DeepSeekBalanceClient(apiKeyProvider: { [weak self] in
            self?.secretStore.get(BalanceFormatting.apiKeyAccount)
        }),
        repository: AppServices.shared.repository,
        interval: 60,
        onAlert: { [weak self] balances in self?.handle(balances) })

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let settings = AppServices.shared.settings
        alertEngine = AlertEngine(
            thresholdProvider: { settings.threshold },
            notifier: SystemAlertNotifier(),
            loadArmed: { currency in UserDefaults.standard.bool(forKey: "alert_armed_\(currency)") },
            persistArmed: { currency, armed in UserDefaults.standard.set(armed, forKey: "alert_armed_\(currency)") })
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.pollAndApply() }
        }
        pollRequestsCancellable = AppServices.shared.pollRequests.sink { [weak self] in
            Task { await self?.pollAndApply() }
        }
        languageCancellable = AppServices.shared.language.$preference
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.installMainMenu() }
        loopTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pollAndApply()
                let delay = self.scheduler.nextDelay(afterConsecutiveFailures: self.consecutiveFailures)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func pollAndApply() async {
        do {
            let response = try await scheduler.pollOnce()
            consecutiveFailures = 0
            await MainActor.run {
                AppServices.shared.state.apply(response)
                AppServices.shared.samplesDidChange.send(Date())
            }
        } catch {
            consecutiveFailures += 1
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            await MainActor.run { AppServices.shared.state.applyError(message) }
        }
    }

    /// A minimal main menu so ⌘Q always works even if the menu bar
    /// icon is hidden behind third-party bar managers (e.g. Bartender).
    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: AppServices.shared.language.t("menu.quitApp"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func handle(_ balances: [BalanceInfo]) {
        guard AppServices.shared.settings.notificationsEnabled else { return }
        Task { @MainActor in
            _ = self.alertEngine?.evaluate(balances: balances)
        }
    }
}
