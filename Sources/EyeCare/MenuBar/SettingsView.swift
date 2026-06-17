import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prefs: Preferences

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("Основное", systemImage: "gearshape") }
            tipsTab
                .tabItem { Label("Советы", systemImage: "heart.text.square") }
        }
        .frame(width: 480, height: 520)
        .padding()
    }

    // MARK: - Основное

    private var generalTab: some View {
        Form {
            Section("Глаза") {
                Toggle("Перерывы для глаз", isOn: $prefs.eyeEnabled)
                Toggle("Пошаговый перерыв (моргание → вдаль → расслабление)", isOn: $prefs.guidedEyeFlow)
                stepperRow("Интервал", value: $prefs.eyeIntervalMinutes,
                           range: 5...60, step: 5, unit: "мин")
                stepperRow("Длительность", value: $prefs.eyeDurationSeconds,
                           range: 10...30, step: 5, unit: "сек")
            }

            Section("Разминка") {
                Toggle("Напоминания встать", isOn: $prefs.moveEnabled)
                stepperRow("Интервал", value: $prefs.moveIntervalMinutes,
                           range: 20...120, step: 5, unit: "мин")
                stepperRow("Длительность разминки", value: $prefs.moveDurationMinutes,
                           range: 2...10, step: 1, unit: "мин")
                stepperRow("Повтор напоминания", value: $prefs.snoozeMinutes,
                           range: 5...30, step: 5, unit: "мин")
            }

            Section("Умная пауза") {
                stepperRow("Считать «отошёл» после", value: idleMinutesBinding,
                           range: 1...10, step: 1, unit: "мин")
                Toggle("Пауза в полноэкранном режиме", isOn: $prefs.pauseInFullscreen)
            }

            Section("Прочее") {
                Toggle("Звук уведомления", isOn: $prefs.soundEnabled)
                Toggle("Запускать при входе в систему",
                       isOn: Binding(get: { prefs.launchAtLogin },
                                     set: { prefs.launchAtLogin = $0 }))
                if let err = prefs.loginItemError {
                    Label("Не удалось включить автозапуск: \(err)", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Picker("Размер карточек", selection: Binding(
                    get: { prefs.cardScale },
                    set: { prefs.cardScale = $0 })) {
                    ForEach(CardScale.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Тестовый режим (быстрые таймеры: 10с / 20с)", isOn: $prefs.debugFast)
            }
        }
        .formStyle(.grouped)
    }

    private var idleMinutesBinding: Binding<Double> {
        Binding(get: { prefs.idleThresholdSeconds / 60 },
                set: { prefs.idleThresholdSeconds = $0 * 60 })
    }

    private func stepperRow(_ title: String, value: Binding<Double>,
                            range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Советы

    private var tipsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                tip("👁 Глаза", [
                    "Главное — не «смотреть на 6 м», а прервать ближний фокус и полноценно поморгать: за экраном моргаем в 3–4 раза реже → сухость и усталость.",
                    "Монитор на расстоянии вытянутой руки, верх экрана — чуть ниже линии глаз (центр на 10–12 см ниже глаз).",
                    "Убери блики: окно сбоку, а не за/перед монитором. Достаточная, но не резкая подсветка.",
                    "Если глаза сохнут — увлажняющие капли «искусственная слеза» без сосудосуживающих компонентов."
                ])
                tip("🚶 Тело", [
                    "Лучше всего работают частые короткие динамичные паузы: 2–3 минуты лёгкой активности каждые 30–60 минут.",
                    "Встал, прошёлся, потянулся — заметно эффективнее, чем просто посидеть в другой позе.",
                    "Меняй позу и опору; если есть стол с регулировкой высоты — чередуй сидя/стоя."
                ])
                tip("⚙️ Рабочее место", [
                    "Стопы на полу, бёдра параллельно полу, поясница с опорой.",
                    "Локти ~90°, запястья нейтральны, плечи расслаблены.",
                    "Верх монитора на уровне глаз или чуть ниже, экран прямо перед тобой."
                ])
                Text("Это приложение — про напоминания и привычку, а не медицинское лечение. При стойком дискомфорте глаз обратись к офтальмологу.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(4)
        }
    }

    private func tip(_ header: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header).font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(item)
                }
                .font(.callout)
            }
        }
    }
}
