//
//  DismissAlarmIntent.swift
//  iOzZZ
//
//  Live Activity intents for alarm interaction.
//  - DismissAlarmIntent: Opens app to show captcha (secondary button)
//  - SnoozeAlarmIntent: Stops alarm and re-schedules it (stop button)
//

import AppIntents
import AlarmKit
import SwiftData

/// Intent triggered by the "Dismiss" secondary button on the alarm Live Activity.
/// Opens the app so the user must solve a captcha before the alarm is actually stopped.
struct DismissAlarmIntent: LiveActivityIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Dismiss Alarm"
    nonisolated(unsafe) static var description = IntentDescription("Opens the app to dismiss the alarm with a captcha")
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Alarm Identifier")
    var alarmIdentifier: String

    init() {
        self.alarmIdentifier = ""
    }

    init(alarmIdentifier: String) {
        self.alarmIdentifier = alarmIdentifier
    }

    func perform() async throws -> some IntentResult {
        // Post notification so the app shows the captcha view
        NotificationCenter.default.post(
            name: .dismissAlarmRequested,
            object: nil,
            userInfo: ["alarmIdentifier": alarmIdentifier]
        )
        return .result()
    }
}

/// Intent triggered by the "Snooze" stop button.
/// Checks snooze limit and either snoozes or forces dismiss.
struct SnoozeAlarmIntent: LiveActivityIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Snooze Alarm"
    nonisolated(unsafe) static var description = IntentDescription("Snoozes the alarm")
    nonisolated(unsafe) static var openAppWhenRun = false

    @Parameter(title: "Alarm Identifier")
    var alarmIdentifier: String

    init() {
        self.alarmIdentifier = ""
    }

    init(alarmIdentifier: String) {
        self.alarmIdentifier = alarmIdentifier
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: alarmIdentifier) else {
            return .result()
        }

        // Stop the alarm first
        try? AlarmManager.shared.stop(id: uuid)

        // Post notification for snooze tracking
        NotificationCenter.default.post(
            name: .alarmSnoozed,
            object: nil,
            userInfo: ["alarmIdentifier": alarmIdentifier]
        )

        return .result()
    }
}

// MARK: - UUID Identifiable

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
