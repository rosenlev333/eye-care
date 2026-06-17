import Combine

/// Команды от UI к AppDelegate (открыть настройки, тесты, выход).
@MainActor
final class AppCommands: ObservableObject {
    var openSettings: () -> Void = {}
    var testEye: () -> Void = {}
    var testMove: () -> Void = {}
    var quit: () -> Void = {}
}
