import Testing
import Foundation
@testable import EyeCare

@MainActor
final class TestClock {
    var current = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { current.addTimeInterval(seconds) }
}

@MainActor
final class MockActivity: ActivityProviding {
    var idleSeconds: Double = 0
    var isLocked = false
    var isSleeping = false
}

@MainActor
final class MockFullscreen: FullscreenProviding {
    var isFullscreen = false
}

/// Связка scheduler + моки + управляемые часы. debugFast → eye 10с, move 20с,
/// snooze 15с, длительность разминки 5с, порог ухода 4с.
@MainActor
final class Harness {
    let prefs = Preferences.shared
    let idle = MockActivity()
    let full = MockFullscreen()
    let clock = TestClock()
    let scheduler: BreakScheduler
    var eyeShows = 0
    var moveShows = 0

    init() {
        prefs.debugFast = true
        prefs.eyeEnabled = true
        prefs.moveEnabled = true
        prefs.pauseInFullscreen = true
        prefs.idleThresholdSeconds = 180

        let c = clock
        scheduler = BreakScheduler(prefs: prefs, idle: idle, fullscreen: full, now: { c.current })
        scheduler.onShowEyeBreak = { [weak self] in self?.eyeShows += 1; return true }
        scheduler.onShowMoveCard = { [weak self] in self?.moveShows += 1; return true }
        scheduler.onHideEyeBreak = {}
        scheduler.onHideMoveCard = {}
    }

    func tick(_ n: Int) { for _ in 0..<n { scheduler.tick() } }
}

@Suite(.serialized) @MainActor
struct BreakSchedulerTests {

    // 1) Полноэкранное видео без ввода НЕ засчитывается как уход.
    @Test func fullscreenWithoutInputIsNotAway() {
        let h = Harness()
        h.prefs.eyeEnabled = false
        h.idle.idleSeconds = 10_000
        h.full.isFullscreen = true

        h.tick(3)

        #expect(h.scheduler.state == .pausedFullscreen)
        #expect(h.scheduler.debugAway == false)
    }

    // 2) Блокировка = пауза в тике; зачёт отдыха только по callback разблокировки с длительностью.
    @Test func lockPausesAndCreditsOnUnlock() {
        let h = Harness()
        h.prefs.eyeEnabled = false
        h.tick(3)
        #expect(h.scheduler.notStoodSeconds == 3)

        h.idle.isLocked = true
        h.tick(1)
        #expect(h.scheduler.state == .pausedIdle)
        #expect(h.scheduler.debugAway == true)
        #expect(h.scheduler.notStoodSeconds == 3)   // в паузе не растёт и не сбрасывается

        h.idle.isLocked = false
        h.scheduler.creditConfirmedAway(10)         // длительность блокировки >= 5с
        #expect(h.scheduler.notStoodSeconds == 0)
    }

    // 3) Сон засчитывается как отдых (creditConfirmedAway), короткий — нет.
    @Test func sleepCreditedViaCallback() {
        let h = Harness()
        h.prefs.eyeEnabled = false
        h.tick(8)
        #expect(h.scheduler.notStoodSeconds == 8)

        h.scheduler.creditConfirmedAway(2)          // < 5с — не засчитываем
        #expect(h.scheduler.notStoodSeconds == 8)

        h.scheduler.creditConfirmedAway(30)         // >= 5с — отдых
        #expect(h.scheduler.notStoodSeconds == 0)
    }

    // 3b) ГЛАВНОЕ: «нет ввода» (читаешь/смотришь не в fullscreen) НЕ засчитывает отдых.
    @Test func plainIdleDoesNotCreditRest() {
        let h = Harness()
        h.prefs.eyeEnabled = false
        h.tick(5)
        #expect(h.scheduler.notStoodSeconds == 5)

        h.idle.idleSeconds = 10_000                 // нет ввода, но не lock/sleep/fullscreen
        h.tick(3)
        #expect(h.scheduler.state == .pausedInactive)
        #expect(h.scheduler.notStoodSeconds == 5)   // пауза, без зачёта

        h.idle.idleSeconds = 0                       // подвигал мышь
        h.tick(1)
        #expect(h.scheduler.notStoodSeconds == 6)   // продолжил с того же места, НЕ сброс
    }

    // 3c) Выключение напоминаний во время разминки отменяет её без ложного зачёта.
    @Test func disablingMoveDuringBreakCancels() {
        let h = Harness()
        h.prefs.eyeEnabled = false
        h.tick(5)
        h.scheduler.startBreakNow()
        #expect(h.scheduler.isOnBreak == true)

        h.prefs.moveEnabled = false
        h.tick(1)
        #expect(h.scheduler.isOnBreak == false)
        #expect(h.scheduler.state == .running)
        #expect(h.scheduler.notStoodSeconds == 5)   // без ложного зачёта (не сброшено в 0)
    }

    // 4) «Ещё работаю» включает snooze — карточка не выскакивает сразу снова.
    @Test func keepWorkingSnooze() {
        let h = Harness()
        h.prefs.eyeEnabled = false

        h.tick(20)               // overdue → первый показ
        #expect(h.moveShows == 1)

        h.scheduler.moveKeepWorking()
        h.tick(10)               // < snooze(15)
        #expect(h.moveShows == 1)

        h.tick(5)                // 35 → снова
        #expect(h.moveShows == 2)
    }

    // 5) Разминка во время глазной карточки показывается после её закрытия.
    @Test func pendingMoveAfterEye() {
        let h = Harness()
        h.tick(20)
        #expect(h.eyeShows == 1)
        #expect(h.scheduler.moveCardShowing == false)

        let before = h.moveShows
        h.scheduler.eyeBreakClosed()
        #expect(h.moveShows == before + 1)
        #expect(h.scheduler.moveCardShowing == true)
    }

    // 6) Границы фаз глазного перерыва 0/3/7/15/20 (pure helper).
    @Test func eyePhaseBoundaries() {
        func title(_ e: Double) -> String { EyePhase.phase(elapsed: e, duration: 20, guided: true).title }
        #expect(title(0) == "Старт")
        #expect(title(2.9) == "Старт")
        #expect(title(3) == "Моргание")
        #expect(title(6.9) == "Моргание")
        #expect(title(7) == "Дальний фокус")
        #expect(title(14.9) == "Дальний фокус")
        #expect(title(15) == "Расслабление")
        #expect(title(20) == "Расслабление")
        #expect(EyePhase.phase(elapsed: 5, duration: 20, guided: false).title == "Перерыв для глаз")
    }
}
