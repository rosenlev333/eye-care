import AppKit

@main
struct EyeCareMain {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            // accessory: живём в menu bar, без иконки в Dock (дублирует LSUIElement)
            app.setActivationPolicy(.accessory)
            app.run()
        }
    }
}
