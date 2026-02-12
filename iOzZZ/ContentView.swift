//
//  ContentView.swift
//  iOzZZ
//
//  Root content view with navigation stack and snooze handling logic.
//  Coordinates max snooze limit enforcement and alarm re-scheduling.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var alarms: [AlarmModel]

    var body: some View {
        NavigationStack {
            AlarmListView()
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.20), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onReceive(NotificationCenter.default.publisher(for: .handleSnoozeInApp)) { notification in
            guard let idString = notification.userInfo?["alarmIdentifier"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                return
            }
            handleSnooze(alarmID: uuid)
        }
    }

    /// Handles snooze button tap with max snooze limit enforcement.
    ///
    /// This is called when the user taps "Snooze" on the alarm notification.
    /// The logic implements smart snooze limiting to prevent infinite snoozing:
    ///
    /// Flow:
    /// 1. Increment snooze count for this alarm
    /// 2. Check if max snoozes reached (if configured)
    ///    - If limit reached: Force captcha instead (must solve to dismiss)
    ///    - If under limit: Re-schedule alarm for snooze duration
    /// 3. Save snooze count to persistence
    ///
    /// Example: maxSnoozes = 3, snoozeDuration = 5 min
    /// - Snooze 1: Alarm re-fires in 5 min (2 remaining)
    /// - Snooze 2: Alarm re-fires in 5 min (1 remaining)
    /// - Snooze 3: Alarm re-fires in 5 min (0 remaining)
    /// - Snooze 4: BLOCKED → Captcha forced (must wake up!)
    ///
    /// - Parameter alarmID: UUID of the alarm that was snoozed
    private func handleSnooze(alarmID: UUID) {
        guard let alarm = alarms.first(where: { $0.id == alarmID }) else {
            print("⚠️ Alarm not found for snooze: \(alarmID)")
            return
        }

        // Track snooze usage
        alarm.currentSnoozeCount += 1
        print("😴 Snooze #\(alarm.currentSnoozeCount) for alarm: \(alarm.label)")

        // Enforce max snooze limit
        if alarm.maxSnoozes > 0 && alarm.currentSnoozeCount >= alarm.maxSnoozes {
            print("🚫 Max snoozes (\(alarm.maxSnoozes)) reached! Forcing dismiss...")

            // No more snoozing allowed - force user to solve captcha
            NotificationCenter.default.post(
                name: .dismissAlarmRequested,
                object: nil,
                userInfo: ["alarmIdentifier": alarmID.uuidString]
            )
        } else {
            print("✅ Snoozing... will re-fire in \(alarm.snoozeDurationMinutes) minutes")
            print("   Snoozes remaining: \(alarm.maxSnoozes > 0 ? "\(alarm.maxSnoozes - alarm.currentSnoozeCount)" : "unlimited")")

            // Still under limit - re-schedule alarm for later
            Task {
                try? await AlarmService.shared.snoozeAlarm(alarm)
            }
        }

        // Persist snooze count
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AlarmModel.self, NFCTagModel.self], inMemory: true)
}
