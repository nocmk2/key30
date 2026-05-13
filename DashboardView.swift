import SwiftUI
import AppKit

enum DashboardTab: Int, Hashable {
    case settings = 0
    case debug = 1
    case about = 2
}

final class DashboardState: ObservableObject {
    @Published var selectedTab: DashboardTab = .settings
}

struct DashboardView: View {
    @ObservedObject var state: DashboardState
    @ObservedObject var monitor: KeyMonitor
    @ObservedObject var settings: AppSettings
    var onSettingsChanged: () -> Void

    var body: some View {
        TabView(selection: $state.selectedTab) {
            SettingsView(
                monitor: monitor,
                settings: settings,
                onSettingsChanged: onSettingsChanged
            )
            .tabItem {
                Label(settings.language == .english ? "Settings" : "设置", systemImage: "gear")
            }
            .tag(DashboardTab.settings)

            DebugView()
                .environmentObject(settings)
                .tabItem {
                    Label(settings.language == .english ? "Debug" : "调试", systemImage: "ladybug")
                }
                .tag(DashboardTab.debug)

            AboutView(settings: settings)
                .tabItem {
                    Label(settings.language == .english ? "About" : "关于", systemImage: "info.circle")
                }
                .tag(DashboardTab.about)
        }
        .frame(minWidth: 700, minHeight: 600)
    }
}

struct AboutView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "keyboard.badge.eye")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 112, height: 112)
                .foregroundStyle(.blue, .secondary)

            Text("Key30")
                .font(.largeTitle)
                .bold()

            Text("Version 1.0")
                .foregroundColor(.secondary)

            Text(settings.language == .english
                 ? "A focused macOS keyboard hold observer extracted from Capsule's early Debug and Settings features."
                 : "从 Capsule 早期 Debug 与 Settings 功能中抽取出来的独立 macOS 按键长按观察工具。")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            VStack(alignment: .leading, spacing: 8) {
                Label(settings.language == .english ? "Observe physical keys globally after Accessibility permission is granted." : "授予辅助功能权限后全局观察物理按键。", systemImage: "checkmark.circle")
                Label(settings.language == .english ? "Tune hold threshold in milliseconds." : "以毫秒精度调整长按触发阈值。", systemImage: "checkmark.circle")
                Label(settings.language == .english ? "Use Debug mode to inspect key codes and durations." : "使用调试模式查看键值与持续时长。", systemImage: "checkmark.circle")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.top, 8)

            Spacer()
        }
        .padding(40)
    }
}
