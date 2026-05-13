import SwiftUI
import AppKit

final class AppSettings: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case simplifiedChinese = "zh-Hans"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .english:
                return "English"
            case .simplifiedChinese:
                return "简体中文"
            }
        }
    }

    enum ModifierKey: String, CaseIterable, Identifiable {
        case command = "Command"
        case control = "Control"
        case option = "Option"
        case shift = "Shift"
        case capsLock = "Caps Lock"
        case function = "Function"

        var id: String { rawValue }

        func localizedName(for language: Language) -> String {
            switch (self, language) {
            case (.command, .english): return "Command"
            case (.command, .simplifiedChinese): return "Command 指令键"
            case (.control, .english): return "Control"
            case (.control, .simplifiedChinese): return "Control 控制键"
            case (.option, .english): return "Option"
            case (.option, .simplifiedChinese): return "Option 选项键"
            case (.shift, .english): return "Shift"
            case (.shift, .simplifiedChinese): return "Shift 上档键"
            case (.capsLock, .english): return "Caps Lock"
            case (.capsLock, .simplifiedChinese): return "Caps Lock 大写锁定"
            case (.function, .english): return "Function"
            case (.function, .simplifiedChinese): return "Function 功能键"
            }
        }
    }

    struct ColorComponents: Codable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double

        init(color: NSColor) {
            let calibrated = color.usingColorSpace(.sRGB) ?? color
            red = Double(calibrated.redComponent)
            green = Double(calibrated.greenComponent)
            blue = Double(calibrated.blueComponent)
            alpha = Double(calibrated.alphaComponent)
        }

        func toColor() -> Color {
            Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }
    }

    struct CapsuleGradient: Codable {
        var primary: ColorComponents
        var secondary: ColorComponents

        func colors() -> [Color] {
            [primary.toColor(), secondary.toColor()]
        }
    }

    private enum Keys {
        static let language = "key30.language"
        static let thresholdSeconds = "key30.thresholdSeconds"
        static let modifierColors = "key30.modifierColors"
        static let soundEnabled = "key30.soundEnabled"
    }

    @Published var language: Language {
        didSet {
            userDefaults.set(language.rawValue, forKey: Keys.language)
        }
    }

    @Published var thresholdSeconds: Double {
        didSet {
            let clamped = min(max(thresholdSeconds, 0.1), 10.0)
            if thresholdSeconds != clamped {
                thresholdSeconds = clamped
                return
            }
            userDefaults.set(thresholdSeconds, forKey: Keys.thresholdSeconds)
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            userDefaults.set(soundEnabled, forKey: Keys.soundEnabled)
        }
    }

    @Published private var modifierGradients: [String: CapsuleGradient] {
        didSet {
            persistModifierGradients()
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let storedLanguage = userDefaults.string(forKey: Keys.language),
           let value = Language(rawValue: storedLanguage) {
            language = value
        } else {
            language = .simplifiedChinese
        }

        let storedThreshold = userDefaults.double(forKey: Keys.thresholdSeconds)
        thresholdSeconds = storedThreshold > 0 ? min(max(storedThreshold, 0.1), 10.0) : 0.15

        if userDefaults.object(forKey: Keys.soundEnabled) != nil {
            soundEnabled = userDefaults.bool(forKey: Keys.soundEnabled)
        } else {
            soundEnabled = true
        }

        if let data = userDefaults.data(forKey: Keys.modifierColors),
           let decoded = try? JSONDecoder().decode([String: CapsuleGradient].self, from: data) {
            modifierGradients = decoded
        } else {
            modifierGradients = AppSettings.defaultModifierGradients()
        }
    }

    func updateGradient(for modifier: ModifierKey, primary: Color, secondary: Color) {
        let primaryComponents = ColorComponents(color: NSColor(primary))
        let secondaryComponents = ColorComponents(color: NSColor(secondary))
        modifierGradients[modifier.rawValue] = CapsuleGradient(primary: primaryComponents, secondary: secondaryComponents)
    }

    func gradient(for modifier: ModifierKey) -> CapsuleGradient {
        modifierGradients[modifier.rawValue] ?? AppSettings.defaultGradient(for: modifier)
    }

    func colors(forKeyName keyName: String) -> [Color] {
        if let modifier = ModifierKey(rawValue: keyName) {
            return gradient(for: modifier).colors()
        }

        let palette = AppSettings.coolPalette
        var hasher = Hasher()
        hasher.combine(keyName)
        let hashValue = UInt(bitPattern: hasher.finalize())
        let index = Int(hashValue % UInt(palette.count))
        return [palette[index].primary.toColor(), palette[index].secondary.toColor()]
    }

    func idleGradient() -> [Color] {
        AppSettings.idleGradient.colors()
    }

    private func persistModifierGradients() {
        if let data = try? JSONEncoder().encode(modifierGradients) {
            userDefaults.set(data, forKey: Keys.modifierColors)
        }
    }

    private static func defaultModifierGradients() -> [String: CapsuleGradient] {
        var map: [String: CapsuleGradient] = [:]
        for modifier in ModifierKey.allCases {
            map[modifier.rawValue] = defaultGradient(for: modifier)
        }
        return map
    }

    private static func defaultGradient(for modifier: ModifierKey) -> CapsuleGradient {
        switch modifier {
        case .command:
            return CapsuleGradient(
                primary: ColorComponents(color: NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.95, alpha: 1.0)),
                secondary: ColorComponents(color: NSColor(calibratedRed: 0.22, green: 0.42, blue: 0.88, alpha: 1.0))
            )
        case .control:
            return CapsuleGradient(
                primary: ColorComponents(color: NSColor(calibratedRed: 0.24, green: 0.68, blue: 0.87, alpha: 1.0)),
                secondary: ColorComponents(color: NSColor(calibratedRed: 0.16, green: 0.54, blue: 0.78, alpha: 1.0))
            )
        case .option:
            return CapsuleGradient(
                primary: ColorComponents(color: NSColor(calibratedRed: 0.29, green: 0.73, blue: 0.78, alpha: 1.0)),
                secondary: ColorComponents(color: NSColor(calibratedRed: 0.19, green: 0.58, blue: 0.70, alpha: 1.0))
            )
        case .shift:
            return CapsuleGradient(
                primary: ColorComponents(color: NSColor(calibratedRed: 0.36, green: 0.64, blue: 0.94, alpha: 1.0)),
                secondary: ColorComponents(color: NSColor(calibratedRed: 0.28, green: 0.50, blue: 0.86, alpha: 1.0))
            )
        case .capsLock:
            return CapsuleGradient(
                primary: ColorComponents(color: NSColor(calibratedRed: 0.45, green: 0.68, blue: 0.92, alpha: 1.0)),
                secondary: ColorComponents(color: NSColor(calibratedRed: 0.33, green: 0.56, blue: 0.84, alpha: 1.0))
            )
        case .function:
            return CapsuleGradient(
                primary: ColorComponents(color: NSColor(calibratedRed: 0.32, green: 0.62, blue: 0.90, alpha: 1.0)),
                secondary: ColorComponents(color: NSColor(calibratedRed: 0.24, green: 0.48, blue: 0.82, alpha: 1.0))
            )
        }
    }

    private static let coolPalette: [CapsuleGradient] = [
        CapsuleGradient(
            primary: ColorComponents(color: NSColor(calibratedRed: 0.26, green: 0.58, blue: 0.98, alpha: 1.0)),
            secondary: ColorComponents(color: NSColor(calibratedRed: 0.17, green: 0.42, blue: 0.88, alpha: 1.0))
        ),
        CapsuleGradient(
            primary: ColorComponents(color: NSColor(calibratedRed: 0.21, green: 0.72, blue: 0.86, alpha: 1.0)),
            secondary: ColorComponents(color: NSColor(calibratedRed: 0.13, green: 0.58, blue: 0.78, alpha: 1.0))
        ),
        CapsuleGradient(
            primary: ColorComponents(color: NSColor(calibratedRed: 0.35, green: 0.63, blue: 0.92, alpha: 1.0)),
            secondary: ColorComponents(color: NSColor(calibratedRed: 0.27, green: 0.49, blue: 0.85, alpha: 1.0))
        ),
        CapsuleGradient(
            primary: ColorComponents(color: NSColor(calibratedRed: 0.38, green: 0.71, blue: 0.96, alpha: 1.0)),
            secondary: ColorComponents(color: NSColor(calibratedRed: 0.22, green: 0.52, blue: 0.88, alpha: 1.0))
        )
    ]

    private static let idleGradient = CapsuleGradient(
        primary: ColorComponents(color: NSColor(calibratedRed: 0.55, green: 0.63, blue: 0.78, alpha: 0.35)),
        secondary: ColorComponents(color: NSColor(calibratedRed: 0.47, green: 0.55, blue: 0.71, alpha: 0.45))
    )
}
