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
        print("📅 Scheduling alarm: \(alarm.timeString) (\(alarm.label))")

        if !isAuthorized {
            print("⚠️ Not authorized, requesting...")
            let granted = await requestAuthorization()
            guard granted else {
                print("❌ Authorization denied")
                return
            }
        }

        let id = alarm.id
        print("✅ Authorized, scheduling alarm with ID: \(id)")

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

        // Countdown duration: no postAlert (we handle snooze manually)
        let countdownDuration = Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: nil
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

        let result = try await manager.schedule(id: id, configuration: config)

        // Calculate when this will actually fire
        let now = Date()
        let nextFire = Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: now) ?? now
        let actualNextFire = nextFire < now ? Calendar.current.date(byAdding: .day, value: 1, to: nextFire)! : nextFire
        let timeUntil = actualNextFire.timeIntervalSince(now)
        let minutesUntil = Int(timeUntil / 60)

        print("✅ Alarm scheduled successfully")
        print("   - Time: \(alarm.hour):\(String(format: "%02d", alarm.minute))")
        print("   - Repeat: \(alarm.repeatDays.isEmpty ? "One-time" : "\(alarm.repeatDays.count) days")")
        print("   - Captcha: \(alarm.captchaType.rawValue)")
        print("   - Snooze: \(alarm.snoozeDurationMinutes) min")
        print("   - Will fire in: ~\(minutesUntil) minutes (\(actualNextFire.formatted(date: .omitted, time: .shortened)))")
        print("   - Result: \(result)")
    }

    // MARK: - Stop & Cancel

    func stopAlarm(id: UUID) throws {
        try manager.stop(id: id)
    }

    func cancelAlarm(id: UUID) throws {
        print("🗑️ Cancelling alarm: \(id)")
        try manager.cancel(id: id)
        print("✅ Alarm cancelled")
    }

    func snoozeAlarm(_ alarm: AlarmModel) async throws {
        print("😴 Snoozing alarm \(alarm.label) for \(alarm.snoozeDurationMinutes) minutes")

        // Cancel current alarm first
        try? cancelAlarm(id: alarm.id)

        // Calculate snooze time (X minutes from now)
        let now = Date()
        let snoozeTime = Calendar.current.date(byAdding: .minute, value: alarm.snoozeDurationMinutes, to: now)!
        let components = Calendar.current.dateComponents([.hour, .minute], from: snoozeTime)

        // Temporarily modify the alarm time
        let originalHour = alarm.hour
        let originalMinute = alarm.minute
        alarm.hour = components.hour ?? 0
        alarm.minute = components.minute ?? 0

        // Schedule with new time
        try await scheduleAlarm(alarm)

        // Restore original time (for display purposes)
        alarm.hour = originalHour
        alarm.minute = originalMinute

        print("✅ Alarm will re-fire at \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
    }

    // MARK: - Query Alarms

    func listScheduledAlarms() async -> Int {
        // Get all alarm IDs from AlarmKit
        do {
            let alarms = try await manager.alarms
            print("📋 AlarmKit has \(alarms.count) scheduled alarm(s)")
            for alarm in alarms {
                print("   - Alarm ID: \(alarm.id)")
            }
            return alarms.count
        } catch {
            print("❌ Failed to list alarms: \(error)")
            return 0
        }
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
