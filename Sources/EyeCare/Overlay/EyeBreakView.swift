import SwiftUI

/// Карточка перерыва для глаз: 20-секундный пошаговый guided-flow с кольцом-отсчётом.
struct EyeBreakView: View {
    let duration: Double
    let guided: Bool
    let scale: CGFloat
    let onClose: () -> Void

    @State private var start = Date()
    @State private var remaining: Double
    @State private var finished = false

    init(duration: Double, guided: Bool, scale: CGFloat, onClose: @escaping () -> Void) {
        let d = max(1, duration)
        self.duration = d
        self.guided = guided
        self.scale = scale
        self.onClose = onClose
        _remaining = State(initialValue: d)
    }

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var elapsed: Double { duration - remaining }

    private var phase: (title: String, instruction: String) {
        EyePhase.phase(elapsed: elapsed, duration: duration, guided: guided)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 14 * scale) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 8 * scale)
                    Circle()
                        .trim(from: 0, to: max(0, remaining / duration))
                        .stroke(Color.accentColor,
                                style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.05), value: remaining)
                    Text("\(Int(ceil(remaining)))")
                        .font(.system(size: 34 * scale, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 96 * scale, height: 96 * scale)

                Text(phase.title)
                    .font(.system(size: 20 * scale, weight: .bold))
                Text(phase.instruction)
                    .font(.system(size: 14 * scale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 42 * scale)
            }
            .padding(28 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: closeOnce) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18 * scale))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10 * scale)
            .help("Закрыть (Esc)")
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22 * scale))
        .overlay(
            RoundedRectangle(cornerRadius: 22 * scale)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .onReceive(tick) { _ in
            // Считаем от реального времени, а не декрементом: если main loop подвисал
            // или Mac засыпал, фазы и отсчёт останутся привязаны к реальным секундам.
            let elapsedReal = Date().timeIntervalSince(start)
            remaining = max(0, duration - elapsedReal)
            if remaining <= 0 { closeOnce() }
        }
    }

    private func closeOnce() {
        guard !finished else { return }
        finished = true
        onClose()
    }
}
