import SwiftUI

struct MiniDashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var language: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.t("app.title"))
                .font(.headline)
            Text(state.statusText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            if let error = state.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Divider()
            HStack {
                Button(language.t("common.openWindow")) { MainWindowPresenter.show() }
                SettingsLink {
                    Text(language.t("common.settings"))
                }
                Spacer()
                Button(language.t("common.quit")) { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
