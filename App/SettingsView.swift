import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var language: LanguageManager
    private let secretStore = AppServices.shared.secretStore
    @State private var apiKey: String = ""
    @State private var saveMessage: String?
    @State private var saveFailed = false

    var body: some View {
        Form {
            Section {
                SecureField(language.t("settings.apiKeyPlaceholder"), text: $apiKey)
                HStack {
                    Button(language.t("settings.saveKey")) { saveKey() }
                    if let saveMessage {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundStyle(saveFailed ? .red : .green)
                    }
                }
                Text(language.t("settings.keyLocalNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(language.t("settings.account"))
            } footer: {
                Text(apiKey.isEmpty
                     ? language.t("settings.notConfigured")
                     : String(format: language.t("settings.configured"),
                              String(apiKey.prefix(4)), String(apiKey.suffix(4))))
            }
            Section(language.t("settings.alerts")) {
                Toggle(language.t("settings.enableAlerts"), isOn: $settings.notificationsEnabled)
                Stepper(value: $settings.threshold, in: 0...1000, step: 0.5) {
                    Text(String(format: language.t("settings.threshold"),
                                BalanceFormatting.formattedAmount(settings.threshold)))
                }
            }
            Section(language.t("settings.menuBar")) {
                Picker(language.t("settings.displayMode"), selection: $settings.menuBarMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title(language: language.resolved)).tag(mode)
                    }
                }
                Picker(language.t("settings.preferredCurrency"), selection: $settings.preferredCurrency) {
                    Text("CNY").tag("CNY")
                    Text("USD").tag("USD")
                }
            }
            Section(language.t("settings.system")) {
                Picker(language.t("settings.language"), selection: $language.preference) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(Localization.string("language.option.\(lang.rawValue)",
                                                 language: language.resolved))
                            .tag(lang)
                    }
                }
                Toggle(language.t("settings.launchAtLogin"), isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            NSLog("LaunchAtLoginManager failed: \(error)")
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 460)
        .onAppear { apiKey = secretStore.get(BalanceFormatting.apiKeyAccount) ?? "" }
    }

    private func saveKey() {
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            apiKey = trimmed
            saveFailed = false
            if trimmed.isEmpty {
                try secretStore.delete(BalanceFormatting.apiKeyAccount)
                saveMessage = language.t("settings.cleared")
            } else {
                try secretStore.set(trimmed, for: BalanceFormatting.apiKeyAccount)
                saveMessage = language.t("settings.savedRefreshing")
            }
            AppServices.shared.pollRequests.send()
            Task {
                try? await Task.sleep(for: .seconds(2))
                saveMessage = trimmed.isEmpty ? language.t("settings.cleared") : language.t("settings.saved")
            }
        } catch {
            saveFailed = true
            saveMessage = String(format: language.t("settings.saveFailed"), error.localizedDescription)
        }
    }
}
