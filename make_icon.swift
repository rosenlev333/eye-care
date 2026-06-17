import AppKit

// Рендерит мастер-иконку 1024×1024 (скруглённый сине-градиентный квадрат + фигура человека).
// Запуск: swift make_icon.swift  →  icon_1024.png

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let clip = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
clip.addClip()

let grad = NSGradient(colors: [
    NSColor(calibratedRed: 0.27, green: 0.60, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.88, alpha: 1)
])!
grad.draw(in: rect, angle: -90)

// Символ фигуры, перекрашенный в белый
let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .semibold)
if let base = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let tinted = NSImage(size: base.size)
    tinted.lockFocus()
    base.draw(at: .zero, from: NSRect(origin: .zero, size: base.size), operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let r = NSRect(x: (size - base.size.width) / 2,
                   y: (size - base.size.height) / 2,
                   width: base.size.width,
                   height: base.size.height)
    tinted.draw(in: r)
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Не удалось отрендерить иконку\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("icon_1024.png готов")
