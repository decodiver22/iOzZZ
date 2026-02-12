//
//  AlarmService.swift
//  iOzZZ
//
//  Service layer for AlarmKit integration.
//  Handles alarm scheduling, cancellation, snooze re-scheduling, and authorization.
//  Uses manual snooze re-scheduling instead of AlarmKit's postAlert for reliability.
//

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

        // Build stop button = "Snooze"
        let snoozeButton = AlarmButton(
            text: "Snooze",
            textColor: .white,
            systemImageName: "moon.zzz.fill"
        )

        // Build secondary button = "Turn Off" (opens app for captcha)
        let dismissButton = AlarmButton(
            text: "Turn Off",
            textColor: .white,
            systemImageName: "hand.raised.fill"
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

        // Countdown duration: minimal preAlert required by AlarmKit
        // We don't use postAlert since we handle snooze manually
        let countdownDuration = Alarm.CountdownDuration(
            preAlert: 1.0,  // 1 second
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

    /// Manually re-schedules an alarm to fire after the snooze duration.
    ///
    /// This is our custom snooze implementation instead of using AlarmKit's postAlert,
    /// which proved unreliable. The approach:
    /// 1. Cancel the current alarm
    /// 2. Calculate snooze fire time (now + snooze duration)
    /// 3. Temporarily update alarm's hour/minute to match snooze time
    /// 4. Re-schedule alarm (AlarmKit will fire at the new time)
    /// 5. Restore original time (so UI shows the correct display time)
    ///
    /// - Parameter alarm: The alarm to snooze (will be modified temporarily)
    /// - Throws: If alarm scheduling fails
    func snoozeAlarm(_ alarm: AlarmModel) async throws {
        print("😴 Snoozing alarm \(alarm.label) for \(alarm.snoozeDurationMinutes) minutes")

        // Step 1: Cancel current alarm to stop it from re-firing
        try? cancelAlarm(id: alarm.id)

        // Step 2: Calculate when the alarm should re-fire (now + snooze duration)
        let now = Date()
        let snoozeTime = Calendar.current.date(byAdding: .minute, value: alarm.snoozeDurationMinutes, to: now)!
        let components = Calendar.current.dateComponents([.hour, .minute], from: snoozeTime)

        // Step 3: Temporarily update alarm time to the snooze time
        // We need to do this because scheduleAlarm() reads hour/minute from the model
        let originalHour = alarm.hour
        let originalMinute = alarm.minute
        alarm.hour = components.hour ?? 0
        alarm.minute = components.minute ?? 0

        // Step 4: Schedule with the snooze time
        try await scheduleAlarm(alarm)

        // Step 5: Restore original display time
        // This ensures the UI shows "8:00" not "8:05" after a snooze
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

    /// Builds an AlarmKit schedule from our alarm model.
    ///
    /// AlarmKit supports two schedule types:
    /// - `.relative()` for time-of-day alarms (e.g., "8:00 AM every day")
    /// - `.fixed()` for absolute dates (e.g., "Jan 1, 2026 at 9:00 AM")
    ///
    /// We always use `.relative()` since we want alarms to fire at specific times.
    /// For one-time alarms, we use relative without recurrence (fires once, then done).
    /// For recurring alarms, we use weekly recurrence with selected weekdays.
    ///
    /// - Parameter alarm: The alarm model to convert
    /// - Returns: AlarmKit schedule configuration
    private func buildSchedule(for alarm: AlarmModel) -> Alarm.Schedule {
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)

        if alarm.repeatDays.isEmpty {
            // One-time alarm: fires once at the specified time, then auto-cancels
            let relative = Alarm.Schedule.Relative(time: time)
            return .relative(relative)
        } else {
            // Recurring alarm: fires weekly on selected days
            // Convert Calendar weekday values (1=Sun, 2=Mon, etc.) to Locale.Weekday
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
