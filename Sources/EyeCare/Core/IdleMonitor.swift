import AppKit
import IOKit

/// Определяет, отошёл ли пользователь от компа: время бездействия ввода (без спец-разрешений)
/// через IOKit HIDIdleTime + блокировка экрана через distributed notifications.
@MainActor
final class IdleMonitor: ActivityProviding {
    private(set) var isLocked = false
    private(set) var isSleeping = false
    private var sleepStartedAt: Date?
    private var lockStartedAt: Date?

    /// Вызывается при пробуждении с фактической длительностью сна (надёжнее boolean,
    /// т.к. во время сна tick scheduler не выполняется).
    var onWake: ((TimeInterval) -> Void)?

    /// Вызывается при разблокировке с фактической длительностью блокировки.
    var onUnlock: ((TimeInterval) -> Void)?

    func start() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(screenLocked),
                        name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(screenUnlocked),
                        name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)

        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(self, selector: #selector(willSleep),
                         name: NSWorkspace.willSleepNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(didWake),
                         name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func screenLocked() {
        isLocked = true
        lockStartedAt = Date()
    }

    @objc private func screenUnlocked() {
        isLocked = false
        if let start = lockStartedAt {
            onUnlock?(Date().timeIntervalSince(start))
            lockStartedAt = nil
        }
    }

    @objc private func willSleep() {
        isSleeping = true
        sleepStartedAt = Date()
    }

    @objc private func didWake() {
        isSleeping = false
        if let start = sleepStartedAt {
            onWake?(Date().timeIntervalSince(start))
            sleepStartedAt = nil
        }
    }

    /// Секунды с момента последнего ввода (мышь/клавиатура).
    var idleSeconds: Double {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                            IOServiceMatching("IOHIDSystem"),
                                            &iterator) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = unmanagedDict?.takeRetainedValue() as? [String: Any],
              let idle = props["HIDIdleTime"] as? NSNumber else { return 0 }

        // HIDIdleTime в наносекундах.
        return idle.doubleValue / 1_000_000_000.0
    }
}
