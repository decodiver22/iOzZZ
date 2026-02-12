//
//  DebugMenuView.swift
//  iOzZZ
//
//  Debug menu for testing alarm features without waiting.
//  Accessible via triple-tap gesture. Allows manual captcha triggering and alarm status checks.
//  DEBUG builds only.
//

import SwiftUI
import SwiftData

struct DebugMenuView: View {
    let onTestCaptcha: (UUID) -> Void
    let onClose: () -> Void

    @Query private var alarms: [AlarmModel]
    @Environment(\.modelContext) private var modelContext

    @State private var testAlarmCreated = false
    @State private var scheduledAlarmsCount = 0
    @State private var showingAlarmCount = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 20) {
                Text("🐛 Debug Menu")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Triple tap anywhere to toggle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Divider()
                    .background(.white.opacity(0.3))

                // Test Alarm Creator
                VStack(spacing: 12) {
                    Button {
                        createTestAlarm()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "alarm.waves.left.and.right.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create Test Alarm")
                                    .font(.headline)
                                Text("Fires in 90 seconds")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(testAlarmCreated ? .green.opacity(0.6) : .blue.opacity(0.6))
                        )
                    }

                    if testAlarmCreated {
                        Text("✅ Test alarm created! Wait 90 seconds...")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Button {
                        checkScheduledAlarms()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Check AlarmKit Status")
                                    .font(.headline)
                                if showingAlarmCount {
                                    Text("\(scheduledAlarmsCount) alarm(s) in AlarmKit")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("See what's actually scheduled")
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.title2)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.purple.opacity(0.6))
                        )
                    }

                    Button {
                        simulateDismissIntent()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.slash.circle.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Simulate Alarm Dismiss")
                                    .font(.headline)
                                Text("Test captcha trigger (workaround)")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.orange.opacity(0.6))
                        )
                    }
                }

                Divider()
                    .background(.white.opacity(0.3))

                if alarms.isEmpty {
                    Text("No alarms to test")
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Captcha for:")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(alarms) { alarm in
                            Button {
                                print("🧪 Testing captcha for alarm: \(alarm.timeString)")
                                onTestCaptcha(alarm.id)
                                onClose()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(alarm.timeString)
                                            .font(.title3.bold())
                                        Text(alarm.label)
                                            .font(.caption)
                                            .opacity(0.8)
                                        Text("\(alarm.captchaType.rawValue) - \(alarm.mathDifficulty.rawValue)")
                                            .font(.caption2)
                                            .opacity(0.6)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                }
                                .foregroundStyle(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.8)
                                )
                            }
                        }
                    }
                }

                Button {
                    onClose()
                } label: {
                    Text("Close")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.5), radius: 30)
            )
            .padding(32)
        }
    }

    private func createTestAlarm() {
        // Create alarm for 90 seconds (1.5 minutes) from now
        let now = Date()
        let future = Calendar.current.date(byAdding: .second, value: 90, to: now)!
        let components = Calendar.current.dateComponents([.hour, .minute], from: future)

        let testAlarm = AlarmModel(
            label: "🧪 Test Alarm",
            hour: components.hour ?? 12,
            minute: components.minute ?? 0,
            repeatDays: [],
            captchaType: .math,
            mathDifficulty: .easy,
            snoozeDurationMinutes: 1
        )

        modelContext.insert(testAlarm)
        try? modelContext.save()

        Task {
            try? await AlarmService.shared.scheduleAlarm(testAlarm)
            await MainActor.run {
                testAlarmCreated = true
            }
        }

        print("🧪 Test alarm created for \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0)) (90 seconds from now)")
    }

    private func checkScheduledAlarms() {
        Task {
            let count = await AlarmService.shared.listScheduledAlarms()
            await MainActor.run {
                scheduledAlarmsCount = count
                showingAlarmCount = true
            }
        }
    }

    private func simulateDismissIntent() {
        // Simulate what DismissAlarmIntent does - post the notification
        // Use the first enabled alarm
        guard let alarm = alarms.first(where: { $0.isEnabled }) else {
            print("⚠️ No enabled alarms to test")
            return
        }

        print("🧪 Simulating dismiss intent for alarm: \(alarm.id)")
        NotificationCenter.default.post(
            name: .dismissAlarmRequested,
            object: nil,
            userInfo: ["alarmIdentifier": alarm.id.uuidString]
        )
        onClose()
    }
}
