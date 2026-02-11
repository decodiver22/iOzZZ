import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var autoTest = AutoTestMode.shared
    @Query private var alarms: [AlarmModel]

    var body: some View {
        NavigationStack {
            AlarmListView()
        }
        #if DEBUG
        .overlay(alignment: .bottom) {
            if autoTest.isTestRunning {
                VStack(spacing: 8) {
                    Text("🤖 AUTO TEST")
                        .font(.caption.bold())
                    Text(autoTest.testStatus)
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding()
                .background(.blue.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
        }
        .task {
            // Start auto-test after a delay
            try? await Task.sleep(for: .seconds(3))
            autoTest.startAutoTest(modelContext: modelContext)
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .handleSnoozeInApp)) { notification in
            guard let idString = notification.userInfo?["alarmIdentifier"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                return
            }
            handleSnooze(alarmID: uuid)
        }
    }

    private func handleSnooze(alarmID: UUID) {
        guard let alarm = alarms.first(where: { $0.id == alarmID }) else {
            print("⚠️ Alarm not found for snooze: \(alarmID)")
            return
        }

        // Increment snooze count
        alarm.currentSnoozeCount += 1
        print("😴 Snooze #\(alarm.currentSnoozeCount) for alarm: \(alarm.label)")

        // Check if max snoozes reached
        if alarm.maxSnoozes > 0 && alarm.currentSnoozeCount >= alarm.maxSnoozes {
            print("🚫 Max snoozes (\(alarm.maxSnoozes)) reached! Forcing dismiss...")

            // Force captcha instead of snooze
            NotificationCenter.default.post(
                name: .dismissAlarmRequested,
                object: nil,
                userInfo: ["alarmIdentifier": alarmID.uuidString]
            )
        } else {
            print("✅ Snoozing... will re-fire in \(alarm.snoozeDurationMinutes) minutes")
            print("   Snoozes remaining: \(alarm.maxSnoozes > 0 ? "\(alarm.maxSnoozes - alarm.currentSnoozeCount)" : "unlimited")")

            // Re-schedule alarm for snooze duration from now
            Task {
                try? await AlarmService.shared.snoozeAlarm(alarm)
            }
        }

        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AlarmModel.self, NFCTagModel.self], inMemory: true)
}
