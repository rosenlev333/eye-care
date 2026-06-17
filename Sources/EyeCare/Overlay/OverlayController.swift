import AppKit
import SwiftUI

/// Borderless-окно, способное стать key (чтобы работали Esc и клики по кнопкам).
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Управляет одним оверлей-окном по центру экрана: показ с фейдом, закрытие, Esc.
@MainActor
final class OverlayController {
    private var window: NSWindow?
    private var escMonitor: Any?

    var onClosed: (() -> Void)?
    var onEscape: (() -> Void)?

    func show<V: View>(size: NSSize, screen: NSScreen, dismissOnEsc: Bool, @ViewBuilder content: () -> V) {
        let win = KeyableWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.hasShadow = true
        win.isMovableByWindowBackground = false

        let host = NSHostingView(rootView: AnyView(content()))
        host.frame = NSRect(origin: .zero, size: size)
        win.contentView = host

        let sf = screen.frame
        win.setFrameOrigin(NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2))

        win.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            win.animator().alphaValue = 1
        }
        window = win

        if dismissOnEsc {
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // Esc
                    self?.onEscape?()
                    return nil
                }
                return event
            }
        }
    }

    func close() {
        if let m = escMonitor {
            NSEvent.removeMonitor(m)
            escMonitor = nil
        }
        guard let win = window else { return }
        window = nil
        let callback = onClosed
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.orderOut(nil)
            callback?()
        })
    }
}
