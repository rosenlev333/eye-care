import SwiftUI

/// Карточка напоминания встать и пройтись.
struct MoveBreakView: View {
    let scale: CGFloat
    let onRested: () -> Void
    let onKeepWorking: () -> Void

    var body: some View {
        VStack(spacing: 16 * scale) {
            Image(systemName: "figure.walk")
                .font(.system(size: 40 * scale))
                .foregroundStyle(Color.accentColor)

            Text("Пора встать")
                .font(.system(size: 22 * scale, weight: .bold))

            Text("Встань и пройдись 3–5 минут")
                .font(.system(size: 14 * scale))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12 * scale) {
                Button(action: onRested) {
                    Text("Встал / иду")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)

                Button(action: onKeepWorking) {
                    Text("Ещё работаю")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .padding(.top, 4 * scale)
        }
        .padding(28 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22 * scale))
        .overlay(
            RoundedRectangle(cornerRadius: 22 * scale)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}
