import SwiftUI

/// Содержимое поповера в menu bar — быстрые настройки «в 1–2 клика».
struct MenuContentView: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var scheduler: BreakScheduler
    @EnvironmentObject var commands: AppCommands

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Для глаз").font(.headline)
                Spacer()
            }

            Toggle("Перерывы для глаз", isOn: $prefs.eyeEnabled)
            Toggle("Напоминания встать", isOn: $prefs.moveEnabled)

            Divider()

            statusRows

            Divider()

            presets

            Divider()

            if !scheduler.isOnBreak {
                Button {
                    scheduler.startBreakNow()
                } label: {
                    Label("Встаю на разминку", systemImage: "figure.walk.departure")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button {
                if scheduler.state == .pausedManual { scheduler.resumeManual() }
                else { scheduler.pauseOneHour() }
            } label: {
                Label(scheduler.state == .pausedManual ? "Возобновить" : "Пауза на 1 час",
                      systemImage: scheduler.state == .pausedManual ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Тест: глаза") { commands.testEye() }
                Button("Тест: встать") { commands.testMove() }
            }
            .font(.caption)

            if prefs.debugFast {
                debugRows
            }

            Divider()

            HStack {
                Button("Настройки…") { commands.openSettings() }
                Spacer()
                Button("Выход") { commands.quit() }
            }
        }
        .padding(14)
        .frame(width: 290)
    }

    @ViewBuilder
    private var statusRows: some View {
        if scheduler.isOnBreak {
            breakRows
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if prefs.eyeEnabled {
                    Label("До перерыва глаз: \(mmss(scheduler.eyeCountdown))", systemImage: "timer")
                }
                if prefs.moveEnabled {
                    Label("До разминки: \(minsText(scheduler.moveCountdown))", systemImage: "figure.walk")
                    Label("Не вставал: \(minsText(scheduler.notStoodSeconds))", systemImage: "clock")
                        .foregroundStyle(scheduler.notStoodSeconds >= moveWarnSeconds ? Color.orange : Color.primary)
                }
                Text(stateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private var breakRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("На разминке: \(mmss(scheduler.breakElapsed))", systemImage: "figure.walk.motion")
                .font(.callout)
                .foregroundStyle(Color.accentColor)
            Text("Таймеры на паузе. Жми, когда вернулся за комп — или приложение поймёт само по активности.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                scheduler.endBreakAndResume()
            } label: {
                Label("Сел работать", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var presets: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Интервал разминки")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach([60, 75, 90], id: \.self) { m in
                    let selected = Int(prefs.moveIntervalMinutes) == m
                    Button {
                        prefs.moveIntervalMinutes = Double(m)
                    } label: {
                        Text(selected ? "● \(m)м" : "\(m)м")
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? Color.accentColor : Color.gray)
                }
            }
        }
    }

    @ViewBuilder
    private var debugRows: some View {
        Divider()
        VStack(alignment: .leading, spacing: 2) {
            Text("DEBUG").font(.caption2).bold()
            Text("idle \(scheduler.debugIdle)s · lock \(scheduler.debugLocked ? "1" : "0") · sleep \(scheduler.debugSleeping ? "1" : "0")")
            Text("full \(scheduler.debugFullscreen ? "1" : "0") · away \(scheduler.debugAway ? "1" : "0") · break \(scheduler.isOnBreak ? "1" : "0")")
            Text("state: \(stateText)")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moveWarnSeconds: Int {
        prefs.debugFast ? 20 : Int(prefs.moveIntervalMinutes * 60)
    }

    private var stateText: String {
        switch scheduler.state {
        case .running: return "Активно"
        case .pausedIdle: return "Пауза — ты отошёл"
        case .pausedInactive: return "Пауза — нет активности"
        case .pausedFullscreen: return "Пауза — полноэкранный режим"
        case .pausedManual: return "Пауза на 1 час"
        case .onBreak: return "На разминке"
        }
    }

    private func mmss(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    private func minsText(_ s: Int) -> String {
        if s < 60 { return "\(s) сек" }
        return "\(s / 60) мин"
    }
}
