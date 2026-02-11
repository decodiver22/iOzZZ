import Foundation
import AlarmKit
import Observation

@MainActor
@Observable
final class AlarmService {
    static let shared = AlarmService()

    nonisolated(unsafe) private let manager = AlarmManager.shared

    var isAuthorized = false

    private init() {
        isAuthorized = manager.authorizationState == .authorized
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        switch manager.authorizationState {
        case .notDetermined:
            do {
                let state = try await manager.requestAuthorization()
                isAuthorized = state == .authorized
                return isAuthorized
            } catch {
                return false
            }
        case .authorized:
            isAuthorized = true
            return true
        case .denied:
            isAuthorized = false
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Schedule

    func scheduleAlarm(_ alarm: AlarmModel) async throws {
        if !isAuthorized {
            let granted = await requestAuthorization()
            guard granted else { return }
        }

        let id = alarm.id

        // Build stop button = "Snooze" (system handles re-fire via postAlert)
        let snoozeButton = AlarmButton(
            text: "Snooze",
            textColor: .white,
            systemImageName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
        )

        // Build secondary button = "Dismiss" (opens app for captcha)
        let dismissButton = AlarmButton(
            text: "Dismiss",
            textColor: .white,
            systemImageName: "checkmark.circle.fill"
        )

        // Alert presentation: stop = snooze (re-fires), secondary = dismiss (opens app)
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.label),
            stopButton: snoozeButton,
            secondaryButton: dismissButton,
            secondaryButtonBehavior: .custom
        )

        let presentation = AlarmPresentation(alert: alert)

        let attributes = AlarmAttributes<AlarmMetadataType>(
            presentation: presentation,
            metadata: AlarmMetadataType(alarmIdentifier: id.uuidString),
            tintColor: .blue
        )

        // Countdown duration: postAlert = snooze duration
        let snoozeDuration = TimeInterval(alarm.snoozeDurationMinutes * 60)
        let countdownDuration = Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: snoozeDuration
        )

        // Build schedule
        let schedule = buildSchedule(for: alarm)

        // Build intents
        let stopIntent = SnoozeAlarmIntent(alarmIdentifier: id.uuidString)
        let secondaryIntent = DismissAlarmIntent(alarmIdentifier: id.uuidString)

        let config = AlarmManager.AlarmConfiguration<AlarmMetadataType>(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: secondaryIntent
        )

        _ = try await manager.schedule(id: id, configuration: config)
    }

    // MARK: - Stop & Cancel

    func stopAlarm(id: UUID) throws {
        try manager.stop(id: id)
    }

    func cancelAlarm(id: UUID) throws {
        try manager.cancel(id: id)
    }

    // MARK: - Schedule Builder

    private func buildSchedule(for alarm: AlarmModel) -> Alarm.Schedule {
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)

        if alarm.repeatDays.isEmpty {
            // One-time alarm: relative schedule without recurrence
            let relative = Alarm.Schedule.Relative(time: time)
            return .relative(relative)
        } else {
            // Recurring alarm: weekly recurrence on selected days
            let weekdays = alarm.repeatDays.sorted().compactMap { calendarWeekday in
                Locale.Weekday(calendarWeekday)
            }
            let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(weekdays)
            let relative = Alarm.Schedule.Relative(time: time, repeats: recurrence)
            return .relative(relative)
        }
    }
}

// MARK: - Calendar weekday to Locale.Weekday mapping

private extension Locale.Weekday {
    init?(_ calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
