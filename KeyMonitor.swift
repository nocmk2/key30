import Foundation
import AppKit

final class KeyMonitor: ObservableObject {
    @Published private(set) var isMonitoring = false
    @Published private(set) var currentPressedKeys: [UInt16: KeyPressInfo] = [:]
    @Published private(set) var isTypingRecently = false
    @Published private(set) var lastTypedKeyName: String?
    @Published private(set) var showCapsule = false
    @Published private(set) var capsuleInfo: CapsuleInfo?
    @Published var isCapsuleHovered = false

    @Published var thresholdSeconds: Double {
        didSet {
            let clamped = min(max(thresholdSeconds, 0.1), 10.0)
            if thresholdSeconds != clamped {
                thresholdSeconds = clamped
                return
            }
            settings.thresholdSeconds = thresholdSeconds
        }
    }

    struct KeyPressInfo {
        let keyCode: UInt16
        let keyName: String
        let startTime: Date
        var hasTriggered: Bool = false
    }

    struct CapsuleInfo {
        let keyName: String
        let duration: TimeInterval
    }

    private let settings: AppSettings
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var updateTimer: Timer?
    private var capsuleHideTask: DispatchWorkItem?
    private var typingResetTask: DispatchWorkItem?

    init(settings: AppSettings) {
        self.settings = settings
        self.thresholdSeconds = settings.thresholdSeconds
    }

    func start() {
        stop()

        DispatchQueue.main.async { [weak self] in
            self?.currentPressedKeys.removeAll()
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkPressedKeys()
        }

        isMonitoring = true
        print("🟢 Key30 monitoring started")
    }

    func stop() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        updateTimer?.invalidate()
        updateTimer = nil

        currentPressedKeys.removeAll()
        capsuleHideTask?.cancel()
        capsuleHideTask = nil
        typingResetTask?.cancel()
        typingResetTask = nil
        isTypingRecently = false
        lastTypedKeyName = nil
        showCapsule = false
        capsuleInfo = nil
        isMonitoring = false
        print("🔴 Key30 monitoring stopped")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch event.type {
            case .keyDown:
                if self.currentPressedKeys[event.keyCode] == nil {
                    let keyName = KeyNames.name(for: event.keyCode)
                    self.markTypingActivity(keyName: keyName)
                    self.currentPressedKeys[event.keyCode] = KeyPressInfo(
                        keyCode: event.keyCode,
                        keyName: keyName,
                        startTime: Date(),
                        hasTriggered: false
                    )
                }

            case .keyUp:
                self.currentPressedKeys.removeValue(forKey: event.keyCode)
                self.hideCapsuleIfNoTriggeredKeys()

            case .flagsChanged:
                self.handleModifierKey(event)

            default:
                break
            }
        }
    }

    private func handleModifierKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode
        let isPressed = flags.contains(.shift) ||
            flags.contains(.control) ||
            flags.contains(.option) ||
            flags.contains(.command) ||
            flags.contains(.capsLock) ||
            flags.contains(.function)

        if isPressed && currentPressedKeys[keyCode] == nil {
            let keyName = KeyNames.name(for: keyCode)
            currentPressedKeys[keyCode] = KeyPressInfo(
                keyCode: keyCode,
                keyName: keyName,
                startTime: Date(),
                hasTriggered: false
            )
        } else if !isPressed && currentPressedKeys[keyCode] != nil {
            currentPressedKeys.removeValue(forKey: keyCode)
            hideCapsuleIfNoTriggeredKeys()
        }
    }

    private func checkPressedKeys() {
        let now = Date()

        for (keyCode, var info) in currentPressedKeys {
            let duration = now.timeIntervalSince(info.startTime)

            if duration >= thresholdSeconds && !info.hasTriggered {
                info.hasTriggered = true
                currentPressedKeys[keyCode] = info
                triggerCapsule(keyName: info.keyName, duration: duration)
            }
        }
    }

    private func triggerCapsule(keyName: String, duration: TimeInterval) {
        let milliseconds = duration * 1000
        print("🎯 Key30 trigger: \(keyName) - \(String(format: "%.3f", duration))s (\(Int(milliseconds))ms)")
        capsuleInfo = CapsuleInfo(keyName: keyName, duration: duration)
        showCapsule = true

        if settings.soundEnabled {
            NSSound.beep()
        }

        scheduleHideTask()
    }

    func scheduleHideTask() {
        capsuleHideTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isCapsuleHovered {
                self.scheduleHideTask()
                return
            }
            self.showCapsule = false
            self.capsuleHideTask = nil
        }
        capsuleHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
    }

    private func hideCapsuleIfNoTriggeredKeys() {
        let hasActiveCapsule = currentPressedKeys.values.contains(where: { $0.hasTriggered })
        if !hasActiveCapsule {
            capsuleHideTask?.cancel()
            capsuleHideTask = nil
            showCapsule = false
            capsuleInfo = nil
        }
    }

    private func markTypingActivity(keyName: String) {
        lastTypedKeyName = keyName
        isTypingRecently = true

        typingResetTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.isTypingRecently = false
        }
        typingResetTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}
