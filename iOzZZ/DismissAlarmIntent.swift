import AppIntents
import AlarmKit

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
/// The system handles the snooze via postAlert countdown duration.
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
        // Stop the alarm (system re-fires after postAlert duration)
        if let uuid = UUID(uuidString: alarmIdentifier) {
            try? AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let dismissAlarmRequested = Notification.Name("dismissAlarmRequested")
}
