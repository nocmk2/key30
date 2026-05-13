import SwiftUI
import AppKit

private enum CapsuleLayout {
    static let visualWidth: CGFloat = 190
    static let visualHeight: CGFloat = 34
    static let shadowInsetHorizontal: CGFloat = 16
    static let shadowInsetTop: CGFloat = 12
    static let shadowInsetBottom: CGFloat = 24

    static let windowWidth = visualWidth + (shadowInsetHorizontal * 2)
    static let windowHeight = visualHeight + shadowInsetTop + shadowInsetBottom
    static let screenBottomPadding: CGFloat = 12
}

final class CapsuleWindow: NSWindow {
    init() {
        let size = NSSize(width: CapsuleLayout.windowWidth, height: CapsuleLayout.windowHeight)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.minY + CapsuleLayout.screenBottomPadding - CapsuleLayout.shadowInsetBottom
        )

        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class CapsuleDragView: NSView {
    var onDoubleTap: (() -> Void)?
    var onRightTap: (() -> Void)?
    var onDragged: ((NSPoint) -> Void)?
    var onHoverStateChanged: ((Bool) -> Void)?

    private var dragOrigin: NSPoint = .zero
    private var windowOriginAtDragStart: NSPoint = .zero
    private var isDragging = false
    private let dragThreshold: CGFloat = 3.0
    private var trackingArea: NSTrackingArea?

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureTransparency()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTransparency()
    }

    private func configureTransparency() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        trackingArea = newArea
        addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverStateChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverStateChanged?(false)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: isDragging ? .closedHand : .pointingHand)
    }

    override func rightMouseUp(with event: NSEvent) {
        onRightTap?()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleTap?()
            isDragging = false
            return
        }
        dragOrigin = NSEvent.mouseLocation
        windowOriginAtDragStart = window?.frame.origin ?? .zero
        isDragging = false
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDragged(with event: NSEvent) {
        if event.clickCount == 2 { return }

        let current = NSEvent.mouseLocation
        let dx = current.x - dragOrigin.x
        let dy = current.y - dragOrigin.y

        if !isDragging && sqrt(dx * dx + dy * dy) < dragThreshold {
            return
        }

        if !isDragging {
            isDragging = true
            window?.invalidateCursorRects(for: self)
        }

        var newOrigin = NSPoint(
            x: windowOriginAtDragStart.x + dx,
            y: windowOriginAtDragStart.y + dy
        )

        if let window = window,
           let screen = NSScreen.screens.first(where: { $0.frame.contains(current) }) ?? window.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let snapDistance: CGFloat = 20.0
            let padding: CGFloat = 12.0
            let windowWidth = window.frame.width
            let windowHeight = window.frame.height

            if abs(newOrigin.x - (visibleFrame.minX + padding)) < snapDistance {
                newOrigin.x = visibleFrame.minX + padding
            } else if abs(newOrigin.x + windowWidth - (visibleFrame.maxX - padding)) < snapDistance {
                newOrigin.x = visibleFrame.maxX - windowWidth - padding
            } else {
                let centerX = visibleFrame.midX - windowWidth / 2
                if abs(newOrigin.x - centerX) < snapDistance {
                    newOrigin.x = centerX
                }
            }

            if abs(newOrigin.y - (visibleFrame.minY + padding)) < snapDistance {
                newOrigin.y = visibleFrame.minY + padding
            } else if abs(newOrigin.y + windowHeight - (visibleFrame.maxY - padding)) < snapDistance {
                newOrigin.y = visibleFrame.maxY - windowHeight - padding
            }
        }

        window?.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging, let origin = window?.frame.origin {
            onDragged?(origin)
        }
        isDragging = false
        window?.invalidateCursorRects(for: self)
    }
}

struct CapsuleView: View {
    @ObservedObject var viewModel: CapsuleViewModel

    var body: some View {
        let renderedColors = viewModel.renderedColors
        let primary = renderedColors.first ?? Color.gray.opacity(0.4)
        let isHovered = viewModel.isHovered

        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: renderedColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.65), .clear, .white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
                .padding(0.5)

            Capsule()
                .stroke(primary.opacity(isHovered ? 1.0 : 0.8), lineWidth: isHovered ? 1.5 : 1.0)

            if viewModel.isActive, let keyName = viewModel.keyName {
                HStack(spacing: 7) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10, weight: .bold))
                    Text(keyName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    if let duration = viewModel.duration {
                        Text("\(Int(duration * 1000))ms")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .opacity(0.85)
                    }
                }
                .foregroundColor(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            }
        }
        .frame(width: isHovered ? 180 : 170, height: isHovered ? 22 : 20)
        .shadow(color: primary.opacity(isHovered ? 0.55 : 0.35), radius: isHovered ? 13 : 8, x: 0, y: isHovered ? 6 : 4)
        .frame(width: CapsuleLayout.visualWidth, height: CapsuleLayout.visualHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .animation(.easeInOut(duration: 0.25), value: viewModel.colors)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isActive)
    }
}

final class CapsuleViewModel: ObservableObject {
    @Published private(set) var colors: [Color]
    @Published private(set) var isActive = false
    @Published private(set) var keyName: String?
    @Published private(set) var duration: TimeInterval?
    @Published var isHovered = false

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        colors = settings.idleGradient()
    }

    var renderedColors: [Color] {
        if isActive {
            return colors.map { $0.opacity(0.72) }
        }
        return colors
    }

    func activate(for keyName: String, duration: TimeInterval) {
        colors = settings.colors(forKeyName: keyName)
        self.keyName = keyName
        self.duration = duration
        isActive = true
    }

    func reset() {
        colors = settings.idleGradient()
        keyName = nil
        duration = nil
        isActive = false
    }
}

final class CapsuleManager: NSObject, ObservableObject {
    private var window: CapsuleWindow?
    private let viewModel: CapsuleViewModel
    private let settings: AppSettings
    private var userHasCustomPosition: Bool
    private var customOrigin: NSPoint?

    var onDoubleTap: (() -> Void)?
    var onHoverStateChanged: ((Bool) -> Void)?

    private enum PositionKeys {
        static let hasCustomPosition = "key30.capsule.hasCustomPosition"
        static let customX = "key30.capsule.customX"
        static let customY = "key30.capsule.customY"
    }

    init(settings: AppSettings) {
        self.settings = settings
        viewModel = CapsuleViewModel(settings: settings)
        userHasCustomPosition = UserDefaults.standard.bool(forKey: PositionKeys.hasCustomPosition)
        if userHasCustomPosition {
            let x = UserDefaults.standard.double(forKey: PositionKeys.customX)
            let y = UserDefaults.standard.double(forKey: PositionKeys.customY)
            customOrigin = NSPoint(x: x, y: y)
        }
        super.init()
    }

    func show(keyName: String, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.ensureWindow()
            if !self.userHasCustomPosition {
                self.repositionToActiveScreen()
            }
            self.viewModel.activate(for: keyName, duration: duration)
        }
    }

    func reset() {
        DispatchQueue.main.async {
            self.ensureWindow()
            self.viewModel.reset()
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.window?.orderOut(nil)
        }
    }

    private func ensureWindow() {
        if let window = window {
            window.orderFrontRegardless()
            return
        }

        let window = CapsuleWindow()
        let dragView = CapsuleDragView(frame: NSRect(origin: .zero, size: window.frame.size))
        dragView.autoresizingMask = [.width, .height]
        dragView.onDoubleTap = { [weak self] in
            self?.onDoubleTap?()
        }
        dragView.onRightTap = { [weak self] in
            self?.showContextMenu()
        }
        dragView.onHoverStateChanged = { [weak self] isHovering in
            self?.viewModel.isHovered = isHovering
            self?.onHoverStateChanged?(isHovering)
        }
        dragView.onDragged = { [weak self] origin in
            self?.saveCustomPosition(origin)
        }

        let hostingView = NSHostingView(
            rootView: ZStack(alignment: .topLeading) {
                CapsuleView(viewModel: viewModel)
                    .padding(.horizontal, CapsuleLayout.shadowInsetHorizontal)
                    .padding(.top, CapsuleLayout.shadowInsetTop)
                    .padding(.bottom, CapsuleLayout.shadowInsetBottom)
            }
            .frame(
                width: CapsuleLayout.windowWidth,
                height: CapsuleLayout.windowHeight,
                alignment: .topLeading
            )
            .background(Color.clear)
        )
        hostingView.frame = dragView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        dragView.addSubview(hostingView)

        window.contentView = dragView
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.superview?.wantsLayer = true
        window.contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor
        window.alphaValue = 1
        window.orderFrontRegardless()

        if let origin = customOrigin {
            window.setFrameOrigin(origin)
        }

        self.window = window
    }

    private func saveCustomPosition(_ origin: NSPoint) {
        userHasCustomPosition = true
        customOrigin = origin
        UserDefaults.standard.set(true, forKey: PositionKeys.hasCustomPosition)
        UserDefaults.standard.set(Double(origin.x), forKey: PositionKeys.customX)
        UserDefaults.standard.set(Double(origin.y), forKey: PositionKeys.customY)
    }

    private func showContextMenu() {
        let menu = NSMenu(title: "Key30 Options")
        let isEnglish = settings.language == .english

        let settingsItem = NSMenuItem(
            title: isEnglish ? "Settings..." : "设置...",
            action: #selector(triggerSettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let debugItem = NSMenuItem(
            title: isEnglish ? "Debug Mode..." : "调试模式...",
            action: #selector(triggerDebug(_:)),
            keyEquivalent: ""
        )
        debugItem.target = self
        menu.addItem(debugItem)

        let resetItem = NSMenuItem(
            title: isEnglish ? "Reset Capsule Position" : "重置胶囊位置",
            action: #selector(resetCustomPosition(_:)),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: isEnglish ? "Quit Key30" : "退出 Key30",
            action: #selector(triggerQuit(_:)),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        if let window = window, let event = NSApp.currentEvent, let contentView = window.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
        }
    }

    @objc private func triggerSettings(_ sender: Any?) {
        Key30AppDelegate.shared.openSettings()
    }

    @objc private func triggerDebug(_ sender: Any?) {
        Key30AppDelegate.shared.openDebug()
    }

    @objc private func triggerQuit(_ sender: Any?) {
        Key30AppDelegate.shared.quit()
    }

    @objc private func resetCustomPosition(_ sender: Any?) {
        userHasCustomPosition = false
        customOrigin = nil
        UserDefaults.standard.set(false, forKey: PositionKeys.hasCustomPosition)
        repositionToActiveScreen()
    }

    private func repositionToActiveScreen() {
        guard let window = window else { return }

        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen = activeScreen else { return }

        let capsuleSize = window.frame.size
        let origin = NSPoint(
            x: screen.visibleFrame.midX - capsuleSize.width / 2,
            y: screen.visibleFrame.minY + CapsuleLayout.screenBottomPadding - CapsuleLayout.shadowInsetBottom
        )
        window.setFrameOrigin(origin)
    }
}
