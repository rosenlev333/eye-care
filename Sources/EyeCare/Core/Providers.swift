import Foundation

/// Источник активности пользователя — абстракция для тестов (мок вместо IOKit/системных событий).
@MainActor
protocol ActivityProviding: AnyObject {
    var idleSeconds: Double { get }
    var isLocked: Bool { get }
    var isSleeping: Bool { get }
}

/// Признак полноэкранного режима — абстракция для тестов.
@MainActor
protocol FullscreenProviding: AnyObject {
    var isFullscreen: Bool { get }
}
