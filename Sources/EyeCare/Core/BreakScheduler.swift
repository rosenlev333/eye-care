import AppKit
import Combine

/// Сердце приложения: два таймера (глаза / разминка), умная пауза, авто-сброс по активности.
@MainActor
final class BreakScheduler: ObservableObject {
    enum State: Equatable {
        case running
        case pausedIdle        // подтверждённый уход: экран заблокирован / Mac спит
        case pausedInactive    // просто нет ввода (читаешь/смотришь) — без зачёта отдыха
        case pausedFullscreen
        case pausedManual
        case onBreak
    }

    private let prefs: Preferences
    private let idle: ActivityProviding
    private let fullscreen: FullscreenProviding
    private let now: () -> Date

    @Published private(set) var state: State = .running
    @Published private(set) var eyeCountdown: Int = 0      // сек до перерыва для глаз
    @Published private(set) var moveCountdown: Int = 0     // сек до напоминания встать
    @Published private(set) var notStoodSeconds: Int = 0   // «не вставал» — время непрерывной работы
    @Published private(set) var isOnBreak = false          // ты на разминке — таймеры стоят
    @Published private(set) var breakElapsed = 0           // сколько уже на разминке, сек

    // Диагностика (показывается в меню в тестовом режиме)
    @Published private(set) var debugIdle = 0
    @Published private(set) var debugLocked = false
    @Published private(set) var debugSleeping = false
    @Published private(set) var debugFullscreen = false
    @Published private(set) var debugAway = false

    // Колбэки в AppDelegate для показа/скрытия оверлеев.
    // onShow* возвращают true, ТОЛЬКО если окно реально показано — иначе не помечаем оверлей активным.
    var onShowEyeBreak: (() -> Bool)?
    var onHideEyeBreak: (() -> Void)?
    var onShowMoveCard: (() -> Bool)?
    var onHideMoveCard: (() -> Void)?

    private var secondsSinceEye = 0
    private var secondsSinceMove = 0

    private var eyeOverlayShowing = false
    private(set) var moveCardShowing = false
    private var moveReminderActive = false
    private var moveReminderPending = false   // разминка пришла, но висела карточка глаз
    private var lastMoveReminderAt = 0

    private var isAway = false
    private var lastIdleSec = 0.0
    private var lastIsFull = false
    private var manualPauseUntil: Date?
    private var breakWasAway = false
    private var breakAwayStartedAt: Date?

    private var timer: Timer?

    init(prefs: Preferences,
         idle: ActivityProviding,
         fullscreen: FullscreenProviding,
         now: @escaping () -> Date = { Date() }) {
        self.prefs = prefs
        self.idle = idle
        self.fullscreen = fullscreen
        self.now = now
    }

    // MARK: - Производные интервалы (с учётом debug-режима)

    private var eyeIntervalSeconds: Int { prefs.debugFast ? 10 : Int(prefs.eyeIntervalMinutes * 60) }
    private var moveIntervalSeconds: Int { prefs.debugFast ? 20 : Int(prefs.moveIntervalMinutes * 60) }
    private var snoozeSeconds: Int { prefs.debugFast ? 15 : Int(prefs.snoozeMinutes * 60) }
    private var moveDurationSeconds: Double { prefs.debugFast ? 5 : prefs.moveDurationMinutes * 60 }
    /// На разминке хватает короткой отлучки, чтобы понять «он встал».
    private var breakAwayThreshold: Double { prefs.debugFast ? 4 : 20 }

    // MARK: - Жизненный цикл

    func start() {
        guard timer == nil else { return }   // защита от повторного запуска

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        updatePublished()
    }

    /// Подтверждённое отсутствие с известной длительностью: разблокировка экрана
    /// (lock→unlock) или пробуждение из сна. Долгое отсутствие = отдых → сброс таймеров.
    func creditConfirmedAway(_ duration: TimeInterval) {
        guard duration >= moveDurationSeconds else { return }
        // Если карточка глаз висела — закрыть, иначе оверлей залипнет.
        if eyeOverlayShowing {
            eyeOverlayShowing = false
            onHideEyeBreak?()
        }
        if isOnBreak {
            endBreakAndResume()
            return
        }
        secondsSinceMove = 0
        secondsSinceEye = 0
        moveReminderActive = false
        moveReminderPending = false
        if moveCardShowing {
            moveCardShowing = false
            onHideMoveCard?()
        }
        isAway = false
        updatePublished()
    }

    // MARK: - Публичные действия

    func pauseOneHour() {
        manualPauseUntil = now().addingTimeInterval(3600)
        // Снимаем любые висящие карточки и transient-состояния, чтобы UI не остался на экране.
        dismissTransientUI()
        moveReminderActive = false
        moveReminderPending = false
        if isOnBreak { endBreakAndResume() }
        state = .pausedManual
        updatePublished()
    }

    func resumeManual() {
        manualPauseUntil = nil
        state = .running
    }

    /// Закрывает активные оверлеи (глаза/разминка) без зачёта.
    private func dismissTransientUI() {
        if eyeOverlayShowing {
            eyeOverlayShowing = false
            onHideEyeBreak?()
        }
        if moveCardShowing {
            moveCardShowing = false
            onHideMoveCard?()
        }
    }

    func triggerEyeNow() { showEyeBreak() }

    /// Тест-кнопка «встать»: показать карточку и вести себя как настоящее напоминание
    /// (выставить snooze-состояние), чтобы после «Ещё работаю» она не выскочила сразу снова.
    func triggerMoveNow() {
        if showMoveCard() {
            moveReminderActive = true
            moveReminderPending = false
            lastMoveReminderAt = secondsSinceMove
        }
    }

    /// Карточка глаз закрыта пользователем / по таймеру.
    func eyeBreakClosed() {
        eyeOverlayShowing = false
        secondsSinceEye = 0
        // Если разминка ждала, пока освободится экран — показать её сейчас.
        if moveReminderPending, showMoveCard() {
            moveReminderActive = true
            moveReminderPending = false
            lastMoveReminderAt = secondsSinceMove
        }
        updatePublished()
    }

    /// «Встал / иду» — НЕ обнуляем таймер сразу, а переходим в режим «на разминке».
    /// Таймеры стоят, пока ты не вернёшься (сам по активности или кнопкой «Сел работать»).
    func moveRested() {
        beginBreak()
    }

    /// Встать на разминку прямо сейчас, не дожидаясь напоминания (кнопка в меню).
    func startBreakNow() {
        beginBreak()
    }

    private func beginBreak() {
        moveCardShowing = false
        onHideMoveCard?()
        isOnBreak = true
        breakWasAway = false
        breakAwayStartedAt = nil
        breakElapsed = 0
        isAway = false
        moveReminderActive = false
        moveReminderPending = false
        state = .onBreak
        updatePublished()
    }

    /// «Сел работать» — конец разминки: сброс таймеров и счётчиков, отсчёт с нуля.
    func endBreakAndResume() {
        isOnBreak = false
        breakWasAway = false
        breakAwayStartedAt = nil
        breakElapsed = 0
        isAway = false
        secondsSinceMove = 0
        secondsSinceEye = 0
        moveReminderActive = false
        moveReminderPending = false
        state = .running
        updatePublished()
    }

    /// «Ещё работаю» — прячем карточку, счётчик «не вставал» продолжает расти,
    /// напоминание повторится через snooze.
    func moveKeepWorking() {
        moveCardShowing = false
        onHideMoveCard?()
        updatePublished()
    }

    private func handleBreakTick(idleSec: Double, isFull: Bool) {
        state = .onBreak
        breakElapsed += 1

        // Полноэкранное видео без ввода НЕ считаем уходом и здесь.
        let away = idle.isLocked || idle.isSleeping || (!isFull && idleSec >= breakAwayThreshold)

        if away {
            // Пользователь реально отошёл — якорим на реальный момент ухода
            // (idle уже накопил idleSec секунд к моменту срабатывания порога).
            if breakAwayStartedAt == nil {
                breakAwayStartedAt = now().addingTimeInterval(-idleSec)
            }
            breakWasAway = true
        } else if breakWasAway, let start = breakAwayStartedAt {
            // Вернулся за комп. Засчитываем разминку только если отлучка была достаточной.
            let duration = now().timeIntervalSince(start)
            if duration >= moveDurationSeconds {
                endBreakAndResume()
                return
            }
            // Слишком короткая отлучка — не засчитываем, ждём настоящего ухода
            // или ручного «Сел работать». (Никакого авто-зачёта без реального ухода.)
            breakWasAway = false
            breakAwayStartedAt = nil
        }
    }

    // MARK: - Показ оверлеев

    private func showEyeBreak() {
        guard !eyeOverlayShowing, !moveCardShowing else { return }
        // Помечаем активным только после подтверждения от AppDelegate, что окно реально показано.
        guard onShowEyeBreak?() == true else { return }
        eyeOverlayShowing = true
        if prefs.soundEnabled { NSSound(named: NSSound.Name("Tink"))?.play() }
    }

    /// Возвращает true, если карточка реально показана (экран свободен и окно создано).
    @discardableResult
    private func showMoveCard() -> Bool {
        guard !moveCardShowing, !eyeOverlayShowing else { return false }
        guard onShowMoveCard?() == true else { return false }
        moveCardShowing = true
        if prefs.soundEnabled { NSSound(named: NSSound.Name("Submarine"))?.play() }
        return true
    }

    // MARK: - Тик раз в секунду

    func tick() {
        // 0) Если фичу выключили во время показа карточки — закрыть её.
        enforceFeatureToggles()

        // Читаем активность/полноэкранность один раз за тик.
        let idleSec = idle.idleSeconds
        let isFull = prefs.pauseInFullscreen && fullscreen.isFullscreen
        lastIdleSec = idleSec
        lastIsFull = isFull

        // 1) Ручная пауза на 1 час
        if let until = manualPauseUntil {
            if now() < until {
                state = .pausedManual
                updatePublished()
                return
            } else {
                manualPauseUntil = nil
            }
        }

        // На разминке: таймеры стоят, ждём возвращения (по активности или вручную)
        if isOnBreak {
            handleBreakTick(idleSec: idleSec, isFull: isFull)
            updatePublished()
            return
        }

        // 2) Подтверждённый уход (lock/sleep) — пауза + закрыть глазную карточку.
        //    Зачёт отдыха (сброс таймеров) происходит НЕ здесь, а по callback при
        //    разблокировке/пробуждении с известной длительностью (creditConfirmedAway).
        if idle.isLocked || idle.isSleeping {
            isAway = true
            if eyeOverlayShowing {
                eyeOverlayShowing = false
                secondsSinceEye = 0
                onHideEyeBreak?()
            }
            state = .pausedIdle
            updatePublished()
            return
        }

        // 3) Просто нет ввода (читаешь/смотришь не в fullscreen) — ТОЛЬКО пауза, без зачёта.
        //    Возврат к активности не сбрасывает таймеры: ты всё это время был у экрана.
        if !isFull && idleSec >= prefs.idleThresholdSeconds {
            isAway = true
            state = .pausedInactive
            updatePublished()
            return
        }

        isAway = false

        // 4) Полноэкранный режим — пауза
        if isFull {
            state = .pausedFullscreen
            updatePublished()
            return
        }

        // 5) Обычный ход
        state = .running

        if prefs.eyeEnabled && !eyeOverlayShowing {
            secondsSinceEye += 1
            if secondsSinceEye >= eyeIntervalSeconds {
                showEyeBreak()
            }
        }

        if prefs.moveEnabled {
            secondsSinceMove += 1
            if secondsSinceMove >= moveIntervalSeconds {
                if !moveReminderActive {
                    // Активным считаем только когда карточка реально показана.
                    if showMoveCard() {
                        moveReminderActive = true
                        moveReminderPending = false
                        lastMoveReminderAt = secondsSinceMove
                    } else {
                        // Экран занят карточкой глаз — покажем сразу после её закрытия.
                        moveReminderPending = true
                    }
                } else if !moveCardShowing && (secondsSinceMove - lastMoveReminderAt) >= snoozeSeconds {
                    if showMoveCard() {
                        moveReminderPending = false
                        lastMoveReminderAt = secondsSinceMove
                    }
                }
            }
        }

        updatePublished()
    }

    /// Закрывает активную карточку / отменяет разминку, если соответствующую фичу выключили.
    private func enforceFeatureToggles() {
        if eyeOverlayShowing && !prefs.eyeEnabled {
            eyeOverlayShowing = false
            secondsSinceEye = 0
            onHideEyeBreak?()
        }
        if !prefs.moveEnabled {
            if isOnBreak {
                cancelBreak()
            }
            if moveCardShowing {
                moveCardShowing = false
                moveReminderActive = false
                moveReminderPending = false
                onHideMoveCard?()
            }
        }
    }

    /// Отмена разминки без зачёта отдыха (например, выключили напоминания во время разминки).
    /// Возвращаемся в running, НЕ трогая счётчики глаз/разминки.
    private func cancelBreak() {
        isOnBreak = false
        breakWasAway = false
        breakAwayStartedAt = nil
        breakElapsed = 0
        state = .running
        updatePublished()
    }

    private func updatePublished() {
        eyeCountdown = max(0, eyeIntervalSeconds - secondsSinceEye)
        moveCountdown = max(0, moveIntervalSeconds - secondsSinceMove)
        notStoodSeconds = secondsSinceMove

        // Диагностика — обновляем здесь, т.к. updatePublished() зовётся в конце каждой ветки тика.
        debugIdle = Int(lastIdleSec)
        debugLocked = idle.isLocked
        debugSleeping = idle.isSleeping
        debugFullscreen = lastIsFull
        debugAway = isAway
    }
}
