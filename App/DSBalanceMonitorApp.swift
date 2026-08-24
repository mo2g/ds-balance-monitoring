import SwiftUI

@main
struct DSBalanceMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var state = AppServices.shared.state
    @ObservedObject private var settings = AppServices.shared.settings

    var body: some Scene {
        MenuBarExtra {
            MiniDashboardView()
                .environmentObject(state)
                .environmentObject(settings)
                .environmentObject(AppServices.shared.language)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(AppServices.shared.language)
        }
    }

    private var menuBarLabel: some View {
        let presentation = MenuBarPresentation.make(statusText: state.statusText, mode: settings.menuBarMode)
        return HStack(spacing: 3) {
            if presentation.showsIcon {
                Image(systemName: "yensign.circle")
            }
            if !presentation.title.isEmpty {
                Text(presentation.title)
            }
        }
        .onChange(of: settings.preferredCurrency) { _, _ in
            state.refresh()
        }
    }
}
