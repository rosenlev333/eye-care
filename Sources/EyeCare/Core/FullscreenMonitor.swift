import AppKit

/// Эвристика fullscreen: переднее окно активного приложения по позиции И размеру совпадает
/// с границами конкретного дисплея (а не просто «такого же размера, как экран»).
/// Сравниваем с CGDisplayBounds — те же координаты (top-left), что и у CGWindowBounds,
/// поэтому учитываем и origin, что отсекает borderless/maximized-окна не на весь экран.
/// Читает только bounds/pid/layer — Screen Recording permission НЕ требуется.
@MainActor
final class FullscreenMonitor: FullscreenProviding {
    func start() {}

    private func activeDisplayRects() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    var isFullscreen: Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let pid = front.processIdentifier

        let displays = activeDisplayRects()
        guard !displays.isEmpty else { return false }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        // Список идёт спереди назад. Берём ПЕРВОЕ (верхнее) обычное окно frontmost-приложения
        // и судим о fullscreen только по нему — чтобы fullscreen-видео в фоновом окне того же
        // приложения на другом мониторе не давало ложную паузу.
        for info in list {
            guard let owner = info[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            for d in displays {
                if abs(bounds.origin.x - d.origin.x) < 2,
                   abs(bounds.origin.y - d.origin.y) < 2,
                   abs(bounds.width - d.width) < 2,
                   abs(bounds.height - d.height) < 2 {
                    return true
                }
            }
            return false   // верхнее окно frontmost-приложения не fullscreen
        }
        return false
    }
}
