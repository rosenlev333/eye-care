import Foundation

/// Чистая функция фазы глазного перерыва — вынесена для тестируемости границ 0/3/7/15/20.
enum EyePhase {
    /// elapsed и duration в секундах. Тайминги масштабируются под duration (база — 20с).
    static func phase(elapsed: Double, duration: Double, guided: Bool) -> (title: String, instruction: String) {
        guard guided else {
            return ("Перерыв для глаз", "Посмотри вдаль, поморгай, расслабь глаза")
        }
        let f = duration / 20.0
        switch elapsed {
        case ..<(3 * f):
            return ("Старт", "Откинься назад. Убери взгляд с экрана.")
        case ..<(7 * f):
            return ("Моргание", "3 медленных полных моргания. Не зажмуривайся.")
        case ..<(15 * f):
            return ("Дальний фокус", "Смотри на дальний объект 6+ метров.")
        default:
            return ("Расслабление", "Расслабь челюсть, плечи и шею. Дыши спокойно.")
        }
    }
}
