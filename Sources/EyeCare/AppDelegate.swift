import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let prefs = Preferences.shared
    let idleMonitor = IdleMonitor()
    let fullscreenMonitor = FullscreenMonitor()
    lazy var scheduler = BreakScheduler(prefs: prefs, idle: idleMonitor, fullscreen: fullscreenMonitor)
    let commands = AppCommands()

    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var eyeController: OverlayController?
    private var moveController: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        wireCommands()
        wireScheduler()

        // Подтверждённое отсутствие (разблокировка/пробуждение) с длительностью → зачёт отдыха.
        idleMonitor.onWake = { [weak self] duration in self?.scheduler.creditConfirmedAway(duration) }
        idleMonitor.onUnlock = { [weak self] duration in self?.scheduler.creditConfirmedAway(duration) }

        idleMonitor.start()
        fullscreenMonitor.start()
        scheduler.start()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "figure.walk.circle",
                              accessibilityDescription: "Перерывы")
            img?.isTemplate = true
            button.image = img
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        let root = MenuContentView()
            .environmentObject(prefs)
            .environmentObject(scheduler)
            .environmentObject(commands)
        popover.contentViewController = NSHostingController(rootView: root)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Команды от UI

    private func wireCommands() {
        commands.openSettings = { [weak self] in self?.openSettings() }
        commands.testEye = { [weak self] in self?.scheduler.triggerEyeNow() }
        commands.testMove = { [weak self] in self?.scheduler.triggerMoveNow() }
        commands.quit = { NSApp.terminate(nil) }
    }

    private func wireScheduler() {
        scheduler.onShowEyeBreak = { [weak self] in self?.showEyeBreak() ?? false }
        scheduler.onHideEyeBreak = { [weak self] in
            self?.eyeController?.close()
        }
        scheduler.onShowMoveCard = { [weak self] in self?.showMoveCard() ?? false }
        scheduler.onHideMoveCard = { [weak self] in
            self?.moveController?.close()
        }
    }

    // MARK: - Оверлеи

    /// Экран, на котором сейчас курсор — чтобы карточка появлялась там, где ты работаешь.
    private func activeScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    /// Возвращает true, только если окно реально показано (иначе scheduler не пометит оверлей активным).
    @discardableResult
    private func showEyeBreak() -> Bool {
        guard eyeController == nil else { return false }
        let screen = activeScreen()
        let scale = prefs.cardScale.factor
        let size = NSSize(width: 380 * scale, height: 300 * scale)

        let controller = OverlayController()
        eyeController = controller
        controller.onClosed = { [weak self] in self?.eyeController = nil }
        controller.onEscape = { [weak self] in self?.closeEyeBreak() }
        controller.show(size: size, screen: screen, dismissOnEsc: true) {
            EyeBreakView(duration: prefs.eyeDurationSeconds,
                         guided: prefs.guidedEyeFlow,
                         scale: scale) { [weak self] in
                self?.closeEyeBreak()
            }
        }
        return true
    }

    /// Пользователь/таймер закрыл карточку глаз → сообщить scheduler и закрыть окно.
    private func closeEyeBreak() {
        guard eyeController != nil else { return }
        scheduler.eyeBreakClosed()
        eyeController?.close()
    }

    /// Возвращает true, только если окно реально показано.
    @discardableResult
    private func showMoveCard() -> Bool {
        guard moveController == nil else { return false }
        let screen = activeScreen()
        let scale = prefs.cardScale.factor
        let size = NSSize(width: 380 * scale, height: 240 * scale)

        let controller = OverlayController()
        moveController = controller
        controller.onClosed = { [weak self] in self?.moveController = nil }
        controller.show(size: size, screen: screen, dismissOnEsc: false) {
            MoveBreakView(scale: scale,
                          onRested: { [weak self] in self?.scheduler.moveRested() },
                          onKeepWorking: { [weak self] in self?.scheduler.moveKeepWorking() })
        }
        return true
    }

    // MARK: - Настройки

    private func openSettings() {
        if settingsWindow == nil {
            let root = SettingsView().environmentObject(prefs)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Для глаз — настройки"
            window.contentViewController = NSHostingController(rootView: root)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
