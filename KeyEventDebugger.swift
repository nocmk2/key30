import Foundation
import AppKit

struct KeyEventRecord: Identifiable {
    enum EventKind {
        case keyDown
        case keyUp
        case modifierDown
        case modifierUp
        case system
    }

    enum SystemMessage: String {
        case monitoringStarted
        case monitoringStopped
        case logCleared
    }

    let id = UUID()
    let timestamp: Date
    let kind: EventKind
    let keyCode: UInt16
    let keyName: String
    let duration: TimeInterval?
    let systemMessage: SystemMessage?
    /// Pre-formatted once at creation; the debug list re-renders all visible
    /// rows on every incoming event, so formatting lazily per render would
    /// invoke DateFormatter ~80x per keystroke.
    let timeString: String

    init(
        timestamp: Date,
        kind: EventKind,
        keyCode: UInt16,
        keyName: String,
        duration: TimeInterval?,
        systemMessage: SystemMessage?
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.keyCode = keyCode
        self.keyName = keyName
        self.duration = duration
        self.systemMessage = systemMessage
        self.timeString = Self.timeFormatter.string(from: timestamp)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

final class KeyEventDebugger: ObservableObject {
    @Published var isDebugging = false
    @Published var events: [KeyEventRecord] = []
    @Published var allEvents: [KeyEventRecord] = []
    @Published var maxEvents = 80
    @Published var maxAllEvents = 5000

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var keyPressStartTimes: [UInt16: Date] = [:]

    func start() {
        stop(logEvent: false)

        events.removeAll()
        keyPressStartTimes.removeAll()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        isDebugging = true
        addSystemEvent(.monitoringStarted)
    }

    func stop(logEvent: Bool = true) {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if logEvent, isDebugging {
            addSystemEvent(.monitoringStopped)
        }

        isDebugging = false
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Capture immediately so the recorded timestamp reflects the actual
        // event time, not when a queued main-thread block eventually runs.
        let keyCode = event.keyCode
        let type = event.type
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let timestamp = Date()

        let work = { [weak self] in
            guard let self = self else { return }

            let keyName = KeyNames.name(for: keyCode)

            switch type {
            case .keyDown:
                if self.keyPressStartTimes[keyCode] == nil {
                    self.keyPressStartTimes[keyCode] = timestamp
                    self.addEvent(KeyEventRecord(
                        timestamp: timestamp,
                        kind: .keyDown,
                        keyCode: keyCode,
                        keyName: keyName,
                        duration: nil,
                        systemMessage: nil
                    ))
                }

            case .keyUp:
                let duration = self.keyPressStartTimes[keyCode].map { timestamp.timeIntervalSince($0) }
                self.keyPressStartTimes.removeValue(forKey: keyCode)

                self.addEvent(KeyEventRecord(
                    timestamp: timestamp,
                    kind: .keyUp,
                    keyCode: keyCode,
                    keyName: keyName,
                    duration: duration,
                    systemMessage: nil
                ))

            case .flagsChanged:
                self.handleFlagsChanged(keyCode: keyCode, flags: flags, keyName: keyName, timestamp: timestamp)

            default:
                break
            }
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func handleFlagsChanged(keyCode: UInt16, flags: NSEvent.ModifierFlags, keyName: String, timestamp: Date) {
        let isPressed = flags.contains(.shift) ||
            flags.contains(.control) ||
            flags.contains(.option) ||
            flags.contains(.command) ||
            flags.contains(.capsLock) ||
            flags.contains(.function)

        if isPressed {
            if keyPressStartTimes[keyCode] == nil {
                keyPressStartTimes[keyCode] = timestamp
                addEvent(KeyEventRecord(
                    timestamp: timestamp,
                    kind: .modifierDown,
                    keyCode: keyCode,
                    keyName: keyName,
                    duration: nil,
                    systemMessage: nil
                ))
            }
        } else {
            let duration = keyPressStartTimes[keyCode].map { timestamp.timeIntervalSince($0) }
            keyPressStartTimes.removeValue(forKey: keyCode)

            addEvent(KeyEventRecord(
                timestamp: timestamp,
                kind: .modifierUp,
                keyCode: keyCode,
                keyName: keyName,
                duration: duration,
                systemMessage: nil
            ))
        }
    }

    private func addEvent(_ record: KeyEventRecord) {
        events.insert(record, at: 0)
        allEvents.append(record)

        if events.count > maxEvents {
            events.removeLast()
        }

        // Amortized trim: removeFirst on a 5000-element array is O(n), so
        // trimming on every event once full would shift ~5000 elements per
        // keystroke. Trim in batches instead (O(1) amortized).
        if allEvents.count > maxAllEvents + trimBatchSize {
            allEvents.removeFirst(allEvents.count - maxAllEvents)
        }
    }

    private let trimBatchSize = 512

    private func addSystemEvent(_ message: KeyEventRecord.SystemMessage) {
        addEvent(KeyEventRecord(
            timestamp: Date(),
            kind: .system,
            keyCode: 0,
            keyName: message.rawValue,
            duration: nil,
            systemMessage: message
        ))
    }

    func clear() {
        events.removeAll()
        allEvents.removeAll()
        keyPressStartTimes.removeAll()
        addSystemEvent(.logCleared)
    }

    func exportLog(language: AppSettings.Language) -> String {
        var log: [String] = []
        let header = language == .english ? "Key Event Debug Log" : "键盘事件调试日志"
        log.append(header)
        let timestampLinePrefix = language == .english ? "Exported: " : "导出时间: "
        log.append(timestampLinePrefix + ISO8601DateFormatter().string(from: Date()))
        log.append(String(repeating: "=", count: 60))
        log.append("")

        for event in allEvents {
            log.append(format(record: event, language: language))
        }

        return log.joined(separator: "\n")
    }

    private func format(record: KeyEventRecord, language: AppSettings.Language) -> String {
        let typeText: String
        switch record.kind {
        case .keyDown:
            typeText = language == .english ? "Key Down" : "按键按下"
        case .keyUp:
            typeText = language == .english ? "Key Up" : "按键释放"
        case .modifierDown:
            typeText = language == .english ? "Modifier Down" : "修饰键按下"
        case .modifierUp:
            typeText = language == .english ? "Modifier Up" : "修饰键释放"
        case .system:
            typeText = language == .english ? "System" : "系统"
        }

        var components: [String] = ["\(record.timeString)", typeText]

        if record.kind == .system, let message = record.systemMessage {
            components.append(Self.systemText(message, language: language))
        } else {
            components.append(record.keyName + " (0x" + String(format: "%02X", record.keyCode) + ")")
            if let duration = record.duration {
                let millis = Int(duration * 1000)
                let durationText: String
                if language == .english {
                    durationText = String(format: "Duration: %.3fs (%dms)", duration, millis)
                } else {
                    durationText = String(format: "持续: %.3f秒 (%d毫秒)", duration, millis)
                }
                components.append(durationText)
            }
        }

        return components.joined(separator: " | ")
    }

    static func systemText(_ message: KeyEventRecord.SystemMessage, language: AppSettings.Language) -> String {
        switch (message, language) {
        case (.monitoringStarted, .english): return "Monitoring started"
        case (.monitoringStarted, .simplifiedChinese): return "开始调试监控"
        case (.monitoringStopped, .english): return "Monitoring stopped"
        case (.monitoringStopped, .simplifiedChinese): return "停止调试监控"
        case (.logCleared, .english): return "Log cleared"
        case (.logCleared, .simplifiedChinese): return "记录已清空"
        }
    }
}
