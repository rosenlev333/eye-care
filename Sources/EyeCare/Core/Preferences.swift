import Foundation
import Combine
import CoreGraphics
import ServiceManagement

enum CardScale: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var factor: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.2
        }
    }
    var label: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
}

/// Все настройки приложения. Хранится в UserDefaults, каждое изменение пишется сразу.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let d = UserDefaults.standard

    @Published var eyeEnabled: Bool { didSet { d.set(eyeEnabled, forKey: "eyeEnabled") } }
    @Published var moveEnabled: Bool { didSet { d.set(moveEnabled, forKey: "moveEnabled") } }

    @Published var eyeIntervalMinutes: Double { didSet { d.set(eyeIntervalMinutes, forKey: "eyeIntervalMinutes") } }
    @Published var eyeDurationSeconds: Double { didSet { d.set(eyeDurationSeconds, forKey: "eyeDurationSeconds") } }

    @Published var moveIntervalMinutes: Double { didSet { d.set(moveIntervalMinutes, forKey: "moveIntervalMinutes") } }
    @Published var moveDurationMinutes: Double { didSet { d.set(moveDurationMinutes, forKey: "moveDurationMinutes") } }

    @Published var idleThresholdSeconds: Double { didSet { d.set(idleThresholdSeconds, forKey: "idleThresholdSeconds") } }
    @Published var snoozeMinutes: Double { didSet { d.set(snoozeMinutes, forKey: "snoozeMinutes") } }

    @Published var guidedEyeFlow: Bool { didSet { d.set(guidedEyeFlow, forKey: "guidedEyeFlow") } }
    @Published var pauseInFullscreen: Bool { didSet { d.set(pauseInFullscreen, forKey: "pauseInFullscreen") } }
    @Published var soundEnabled: Bool { didSet { d.set(soundEnabled, forKey: "soundEnabled") } }
    @Published var cardScaleRaw: String { didSet { d.set(cardScaleRaw, forKey: "cardScaleRaw") } }
    @Published var debugFast: Bool { didSet { d.set(debugFast, forKey: "debugFast") } }

    var cardScale: CardScale {
        get { CardScale(rawValue: cardScaleRaw) ?? .medium }
        set { cardScaleRaw = newValue.rawValue }
    }

    /// Текст ошибки регистрации login item (показывается в настройках). nil = всё ок.
    @Published var loginItemError: String?

    /// Автозапуск при входе в систему через SMAppService.
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
                loginItemError = nil
            } catch {
                loginItemError = error.localizedDescription
                NSLog("launchAtLogin error: \(error.localizedDescription)")
            }
            objectWillChange.send()
        }
    }

    private init() {
        d.register(defaults: [
            "eyeEnabled": true,
            "moveEnabled": true,
            "eyeIntervalMinutes": 20.0,
            "eyeDurationSeconds": 20.0,
            "moveIntervalMinutes": 60.0,
            "moveDurationMinutes": 3.0,
            "idleThresholdSeconds": 180.0,
            "snoozeMinutes": 10.0,
            "guidedEyeFlow": true,
            "pauseInFullscreen": true,
            "soundEnabled": true,
            "cardScaleRaw": "medium",
            "debugFast": false
        ])
        eyeEnabled = d.bool(forKey: "eyeEnabled")
        moveEnabled = d.bool(forKey: "moveEnabled")
        eyeIntervalMinutes = d.double(forKey: "eyeIntervalMinutes")
        eyeDurationSeconds = d.double(forKey: "eyeDurationSeconds")
        moveIntervalMinutes = d.double(forKey: "moveIntervalMinutes")
        moveDurationMinutes = d.double(forKey: "moveDurationMinutes")
        idleThresholdSeconds = d.double(forKey: "idleThresholdSeconds")
        snoozeMinutes = d.double(forKey: "snoozeMinutes")
        guidedEyeFlow = d.bool(forKey: "guidedEyeFlow")
        pauseInFullscreen = d.bool(forKey: "pauseInFullscreen")
        soundEnabled = d.bool(forKey: "soundEnabled")
        cardScaleRaw = d.string(forKey: "cardScaleRaw") ?? "medium"
        debugFast = d.bool(forKey: "debugFast")
    }
}
