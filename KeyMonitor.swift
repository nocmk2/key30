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
    private var pendingTriggerTasks: [UInt16: DispatchWorkItem] = [:]
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

        pendingTriggerTasks.values.forEach { $0.cancel() }
        pendingTriggerTasks.removeAll()

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
        // Capture event data immediately: NSEvent must not be retained across
        // threads, and capturing the timestamp here avoids run-loop hop jitter.
        let keyCode = event.keyCode
        let type = event.type
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let timestamp = Date()

        let work = { [weak self] in
            guard let self = self else { return }

            switch type {
            case .keyDown:
                if self.currentPressedKeys[keyCode] == nil {
                    let keyName = KeyNames.name(for: keyCode)
                    self.markTypingActivity(keyName: keyName)
                    self.currentPressedKeys[keyCode] = KeyPressInfo(
                        keyCode: keyCode,
                        keyName: keyName,
                        startTime: timestamp,
                        hasTriggered: false
                    )
                    self.scheduleTrigger(for: keyCode)
                }

            case .keyUp:
                self.cancelTrigger(for: keyCode)
                self.currentPressedKeys.removeValue(forKey: keyCode)
                self.hideCapsuleIfNoTriggeredKeys()

            case .flagsChanged:
                self.handleModifierKey(keyCode: keyCode, flags: flags, timestamp: timestamp)

            default:
                break
            }
        }

        // NSEvent monitors fire on the main thread; run inline to avoid an
        // extra run-loop hop per keystroke.
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func handleModifierKey(keyCode: UInt16, flags: NSEvent.ModifierFlags, timestamp: Date) {
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
                startTime: timestamp,
                hasTriggered: false
            )
            scheduleTrigger(for: keyCode)
        } else if !isPressed && currentPressedKeys[keyCode] != nil {
            cancelTrigger(for: keyCode)
            currentPressedKeys.removeValue(forKey: keyCode)
            hideCapsuleIfNoTriggeredKeys()
        }
    }

    /// Schedules a one-shot trigger exactly at the hold threshold instead of
    /// polling all pressed keys on a 20 Hz timer. Zero wakeups while idle and
    /// millisecond-accurate trigger timing.
    private func scheduleTrigger(for keyCode: UInt16) {
        pendingTriggerTasks[keyCode]?.cancel()

        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingTriggerTasks[keyCode] = nil
            guard let info = self.currentPressedKeys[keyCode], !info.hasTriggered else { return }
            self.currentPressedKeys[keyCode]?.hasTriggered = true
            self.triggerCapsule(keyName: info.keyName, duration: Date().timeIntervalSince(info.startTime))
        }
        pendingTriggerTasks[keyCode] = task
        DispatchQueue.main.asyncAfter(deadline: .now() + thresholdSeconds, execute: task)
    }

    private func cancelTrigger(for keyCode: UInt16) {
        pendingTriggerTasks[keyCode]?.cancel()
        pendingTriggerTasks[keyCode] = nil
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
