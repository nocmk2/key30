import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var monitor: KeyMonitor
    @ObservedObject var settings: AppSettings
    var onSettingsChanged: () -> Void

    @State private var inputText: String = ""
    @State private var isEditingText = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(settings.language == .english ? "Settings" : "设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 12)

                Divider()

                languageSection
                thresholdSection
                behaviorSection
                colorSection
            }
            .padding(24)
        }
        .frame(width: 520, height: 620)
        .onAppear {
            inputText = "\(Int(monitor.thresholdSeconds * 1000))"
        }
        .onChange(of: monitor.thresholdSeconds) { _, newValue in
            if !isEditingText {
                inputText = "\(Int(newValue * 1000))"
            }
            onSettingsChanged()
        }
    }

    private func applyInputValue() {
        isEditingText = true
        defer { isEditingText = false }

        if let milliseconds = Int(inputText.trimmingCharacters(in: .whitespaces)) {
            let clampedMs = max(100, min(10000, milliseconds))
            let seconds = Double(clampedMs) / 1000.0
            monitor.thresholdSeconds = seconds
            inputText = "\(clampedMs)"
        } else {
            inputText = "\(Int(monitor.thresholdSeconds * 1000))"
        }
        onSettingsChanged()
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.language == .english ? "Language" : "界面语言")
                .font(.headline)

            Picker("Language", selection: $settings.language) {
                ForEach(AppSettings.Language.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .onChange(of: settings.language) { _, _ in
                onSettingsChanged()
            }

            Text(settings.language == .english ? "Switches the language for menus, settings, and debug tools." : "切换菜单、设置与调试工具的语言。")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.language == .english ? "Hold Threshold" : "触发时间")
                .font(.headline)

            HStack {
                Slider(value: $monitor.thresholdSeconds, in: 0.1...10.0, step: 0.01)

                VStack(alignment: .trailing, spacing: 2) {
                    let secondsLabel = settings.language == .english ? String(format: "%.3f s", monitor.thresholdSeconds) : String(format: "%.3f 秒", monitor.thresholdSeconds)
                    Text(secondsLabel)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    Text("\(Int(monitor.thresholdSeconds * 1000)) ms")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue.opacity(0.7))
                }
                .frame(width: 80, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Text(settings.language == .english ? "Precise input:" : "精确输入：")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                TextField(settings.language == .english ? "Milliseconds" : "毫秒", text: $inputText, onCommit: {
                    applyInputValue()
                })
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .font(.system(size: 13, design: .monospaced))
                .multilineTextAlignment(.trailing)

                Text("ms")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Button(settings.language == .english ? "Apply" : "应用") {
                    applyInputValue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()
            }

            Text(settings.language == .english ? "Range: 100–10,000 ms (0.10–10.00 s). Use this to match your QMK/Vial tap-hold timing." : "范围：100-10000 毫秒（0.10-10.00 秒）。可用于匹配 QMK/Vial Tap-Hold 时间。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .panelBackground()
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.language == .english ? "Behavior" : "行为")
                .font(.headline)

            Toggle(isOn: $settings.soundEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.language == .english ? "Play sound on trigger" : "触发时播放提示音")
                    Text(settings.language == .english ? "Use the system beep when a key passes the hold threshold." : "当按键超过触发时间时播放系统提示音。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: settings.soundEnabled) { _, _ in
                onSettingsChanged()
            }
        }
        .panelBackground()
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.language == .english ? "Capsule Colors" : "胶囊颜色")
                .font(.headline)

            Text(settings.language == .english ? "Customize gradient colors for modifier keys. Other keys use deterministic cool-toned palettes." : "为修饰键自定义渐变颜色，其它按键默认使用稳定的冷色调。")
                .font(.footnote)
                .foregroundColor(.secondary)

            ForEach(AppSettings.ModifierKey.allCases) { modifier in
                HStack(spacing: 16) {
                    Text(modifier.localizedName(for: settings.language))
                        .frame(width: 180, alignment: .leading)

                    ColorPicker(settings.language == .english ? "Primary" : "主色", selection: Binding(
                        get: { settings.gradient(for: modifier).primary.toColor() },
                        set: { newValue in
                            let current = settings.gradient(for: modifier)
                            settings.updateGradient(for: modifier, primary: newValue, secondary: current.secondary.toColor())
                            onSettingsChanged()
                        }
                    ))
                    .labelsHidden()

                    ColorPicker(settings.language == .english ? "Accent" : "辅助色", selection: Binding(
                        get: { settings.gradient(for: modifier).secondary.toColor() },
                        set: { newValue in
                            let current = settings.gradient(for: modifier)
                            settings.updateGradient(for: modifier, primary: current.primary.toColor(), secondary: newValue)
                            onSettingsChanged()
                        }
                    ))
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }
        }
        .panelBackground()
    }
}

private extension View {
    func panelBackground() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.05))
            )
    }
}
