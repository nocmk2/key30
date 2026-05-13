import SwiftUI
import AppKit

struct DebugView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var debugger = KeyEventDebugger()
    @State private var showStatsView = false
    @State private var showCopied = false

    private var language: AppSettings.Language { settings.language }

    var body: some View {
        VStack(spacing: 0) {
            header
            instructions
            eventList
            controlBar
        }
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showStatsView) {
            StatsDashboardView(debugger: debugger)
                .environmentObject(settings)
        }
        .onDisappear {
            debugger.stop()
        }
    }

    private var header: some View {
        HStack {
            Text(language == .english ? "🔍 Key Event Debugger" : "🔍 按键调试模式")
                .font(.system(size: 24, weight: .bold))

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(debugger.isDebugging ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)

                Text(debugger.isDebugging ? (language == .english ? "Monitoring" : "监控中") : (language == .english ? "Idle" : "未监控"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(debugger.isDebugging ? .green : .gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text(language == .english ? "How to use" : "使用说明")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(language == .english ? "• Press “Start Debugging” then interact with your keyboard to stream events." : "• 点击「开始调试」，按下任意键即可实时查看事件。")
                Text(language == .english ? "• Each row shows the timestamp, event type, key name, key code, and hold duration." : "• 每行包含时间、事件类型、按键名称、键值以及持续时长。")
                Text(language == .english ? "• Ideal for validating QMK/Vial tap-hold timings (e.g. A → Ctrl)." : "• 适合调试 QMK/Vial Tap-Hold 配置（如 A 长按变 Ctrl）。")
                    .foregroundColor(.orange)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
        )
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(language == .english ? "Event Log" : "事件记录")
                    .font(.headline)

                Spacer()

                Text(language == .english ? "Total: \(debugger.events.count)" : "共 \(debugger.events.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Divider()

            if debugger.events.isEmpty {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "keyboard")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))

                    Text(language == .english ? "Waiting for key events…" : "等待按键事件…")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text(language == .english ? "Press “Start Debugging” and hold any key." : "点击「开始调试」，再按任意键。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(debugger.events) { event in
                            EventRow(event: event)
                                .environmentObject(settings)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
        .padding(.top, 12)
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                if debugger.isDebugging {
                    debugger.stop()
                } else {
                    debugger.start()
                }
            }) {
                HStack {
                    Image(systemName: debugger.isDebugging ? "stop.circle.fill" : "play.circle.fill")
                    Text(debugger.isDebugging ? (language == .english ? "Stop" : "停止调试") : (language == .english ? "Start" : "开始调试"))
                }
                .frame(width: 140)
            }
            .buttonStyle(.borderedProminent)
            .tint(debugger.isDebugging ? .red : .green)

            Button(action: {
                debugger.clear()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text(language == .english ? "Clear" : "清空")
                }
                .frame(width: 110)
            }
            .buttonStyle(.bordered)
            .disabled(debugger.events.isEmpty)

            Button(action: {
                showStatsView = true
            }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                    Text(language == .english ? "Statistics" : "统计")
                }
                .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .disabled(debugger.allEvents.isEmpty)

            Button(action: copyLog) {
                HStack {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    Text(showCopied ? (language == .english ? "Copied" : "已复制") : (language == .english ? "Copy Log" : "复制日志"))
                }
                .frame(width: 120)
            }
            .buttonStyle(.bordered)
            .disabled(debugger.allEvents.isEmpty)

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }

    private func copyLog() {
        let log = debugger.exportLog(language: language)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}

struct EventRow: View {
    let event: KeyEventRecord
    @EnvironmentObject var settings: AppSettings

    private var language: AppSettings.Language { settings.language }

    var body: some View {
        Group {
            if event.kind == .system {
                systemRow
            } else {
                keyRow
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(rowBackground)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var keyRow: some View {
        HStack(spacing: 12) {
            Text(event.timeString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(eventTypeText)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 120, alignment: .leading)

            Text(event.keyName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(typeColor)
                .frame(minWidth: 110, alignment: .leading)

            Text("(0x" + String(format: "%02X", event.keyCode) + ")")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            if let duration = event.duration {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    VStack(alignment: .trailing, spacing: 1) {
                        let secondsLabel = String(format: "%.3f", duration)
                        Text(language == .english ? "\(secondsLabel)s" : "\(secondsLabel)秒")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text("\(Int(duration * 1000)) ms")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .opacity(0.75)
                    }
                }
                .foregroundColor(durationColor(duration))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(durationColor(duration).opacity(0.12))
                )
            }
        }
    }

    private var systemRow: some View {
        HStack {
            Text(event.timeString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(systemMessageText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.yellow)

            Spacer()
        }
    }

    private var eventTypeText: String {
        switch event.kind {
        case .keyDown:
            return language == .english ? "Key Down" : "按键按下"
        case .keyUp:
            return language == .english ? "Key Up" : "按键释放"
        case .modifierDown:
            return language == .english ? "Modifier Down" : "修饰键按下"
        case .modifierUp:
            return language == .english ? "Modifier Up" : "修饰键释放"
        case .system:
            return "System"
        }
    }

    private var typeColor: Color {
        switch event.kind {
        case .keyDown, .modifierDown:
            return .blue
        case .keyUp, .modifierUp:
            return .green
        case .system:
            return .primary
        }
    }

    private var rowBackground: Color {
        switch event.kind {
        case .keyDown, .modifierDown:
            return Color.blue.opacity(0.05)
        case .keyUp, .modifierUp:
            return Color.green.opacity(0.05)
        case .system:
            return Color.yellow.opacity(0.12)
        }
    }

    private var systemMessageText: String {
        guard let message = event.systemMessage else {
            return language == .english ? "System event" : "系统事件"
        }
        return KeyEventDebugger.systemText(message, language: language)
    }

    private func durationColor(_ duration: TimeInterval) -> Color {
        switch duration {
        case ..<0.2: return .gray
        case ..<0.5: return .blue
        case ..<1.0: return .orange
        default: return .red
        }
    }
}

struct StatsDashboardView: View {
    @ObservedObject var debugger: KeyEventDebugger
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    private var language: AppSettings.Language { settings.language }

    private var topKeys: [(String, Int)] {
        let keyUps = debugger.allEvents.filter { $0.kind == .keyUp || $0.kind == .modifierUp }
        var counts: [String: Int] = [:]
        for event in keyUps {
            counts[event.keyName, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { $0 }
    }

    private var maxCount: Int {
        topKeys.first?.1 ?? 1
    }

    private var avgDuration: TimeInterval {
        let keyUps = debugger.allEvents
            .filter { $0.kind == .keyUp || $0.kind == .modifierUp }
            .compactMap { $0.duration }
        if keyUps.isEmpty { return 0 }
        return keyUps.reduce(0, +) / Double(keyUps.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(language == .english ? "Session Statistics" : "按键统计数据")
                    .font(.headline)
                Spacer()
                Button(language == .english ? "Done" : "完成") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(spacing: 24) {
                    HStack(spacing: 16) {
                        StatCard(
                            title: language == .english ? "Total Keystrokes" : "总按键次数",
                            value: "\(debugger.allEvents.filter { $0.kind == .keyUp || $0.kind == .modifierUp }.count)",
                            icon: "keyboard.fill",
                            color: .blue
                        )
                        StatCard(
                            title: language == .english ? "Avg Hold Duration" : "平均按住时长",
                            value: String(format: "%.0f ms", avgDuration * 1000),
                            icon: "timer",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(language == .english ? "Most Frequent Keys" : "最常用按键分布")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if topKeys.isEmpty {
                            Text(language == .english ? "Not enough data yet." : "暂无足够数据")
                                .foregroundColor(.secondary)
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(topKeys, id: \.0) { key, count in
                                    HStack {
                                        Text(key)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .frame(width: 80, alignment: .trailing)

                                        GeometryReader { proxy in
                                            let barWidth = proxy.size.width * CGFloat(count) / CGFloat(maxCount)
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.gray.opacity(0.1))
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(colors: [.blue.opacity(0.6), .blue], startPoint: .leading, endPoint: .trailing)
                                                    )
                                                    .frame(width: max(barWidth, 8))
                                            }
                                        }
                                        .frame(height: 16)

                                        Text("\(count)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(width: 40, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.05)))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .frame(width: 500, height: 460)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.05)))
    }
}
