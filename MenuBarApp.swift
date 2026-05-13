import SwiftUI
import AppKit

@main
struct Key30App: App {
    @NSApplicationDelegateAdaptor(Key30AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class Key30AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static var shared: Key30AppDelegate!

    private var statusItem: NSStatusItem!
    private let settings = AppSettings()
    private lazy var monitor = KeyMonitor(settings: settings)
    private lazy var capsuleManager = CapsuleManager(settings: settings)
    private var dashboardWindow: NSWindow?
    private let dashboardState = DashboardState()
    private var capsuleCheckTimer: Timer?
    private var lastShowState = false
    private var lastCapsuleKey: String?
    private var lastCapsuleDuration: TimeInterval?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Key30 launching...")
        setupStatusItem()
        monitor.start()

        capsuleManager.onDoubleTap = { [weak self] in
            self?.openSettings()
        }
        capsuleManager.onHoverStateChanged = { [weak self] isHovering in
            self?.monitor.isCapsuleHovered = isHovering
        }
        capsuleManager.reset()

        capsuleCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.syncCapsule()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func openDashboard(tab: Int = DashboardTab.settings.rawValue) {
        let dashboardTab = DashboardTab(rawValue: tab) ?? .settings
        dashboardState.selectedTab = dashboardTab
        prepareDashboardWindow()

        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() { openDashboard(tab: DashboardTab.settings.rawValue) }
    @objc func openDebug() { openDashboard(tab: DashboardTab.debug.rawValue) }
    @objc func showAbout() { openDashboard(tab: DashboardTab.about.rawValue) }

    @objc func toggleMonitoring() {
        if monitor.isMonitoring {
            monitor.stop()
            capsuleManager.reset()
        } else {
            monitor.start()
        }
        updateMenu()
    }

    @objc func quit() {
        capsuleCheckTimer?.invalidate()
        capsuleCheckTimer = nil
        monitor.stop()
        capsuleManager.hide()
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Key30")
        }
        updateMenu()
    }

    private func updateMenu() {
        let menu = NSMenu()
        let isEnglish = settings.language == .english

        let toggleTitle: String
        if monitor.isMonitoring {
            toggleTitle = isEnglish ? "Pause Monitoring" : "暂停监控"
        } else {
            toggleTitle = isEnglish ? "Start Monitoring" : "开始监控"
        }

        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring), keyEquivalent: "m")
        toggleItem.target = self
        toggleItem.state = monitor.isMonitoring ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: isEnglish ? "Settings" : "设置", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let debugItem = NSMenuItem(title: isEnglish ? "Debug" : "调试", action: #selector(openDebug), keyEquivalent: "d")
        debugItem.target = self
        menu.addItem(debugItem)

        let aboutItem = NSMenuItem(title: isEnglish ? "About" : "关于", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: isEnglish ? "Quit Key30" : "退出 Key30", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func prepareDashboardWindow() {
        guard dashboardWindow == nil else {
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Key30"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: DashboardView(
                state: dashboardState,
                monitor: monitor,
                settings: settings,
                onSettingsChanged: { [weak self] in
                    self?.handleSettingsChanged()
                }
            )
        )
        dashboardWindow = window
    }

    private func handleSettingsChanged() {
        updateMenu()
    }

    private func syncCapsule() {
        if monitor.showCapsule, let info = monitor.capsuleInfo {
            if !lastShowState || lastCapsuleKey != info.keyName || lastCapsuleDuration != info.duration {
                capsuleManager.show(keyName: info.keyName, duration: info.duration)
            }
            lastCapsuleKey = info.keyName
            lastCapsuleDuration = info.duration
        } else if lastShowState {
            lastCapsuleKey = nil
            lastCapsuleDuration = nil
            capsuleManager.reset()
        }

        lastShowState = monitor.showCapsule
    }
}
