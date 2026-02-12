//
//  AlarmModel.swift
//  iOzZZ
//
//  SwiftData model for alarm configurations.
//  The alarm ID is shared between SwiftData and AlarmKit (same UUID).
//  Includes captcha settings, snooze limits, and repeat schedule.
//

import Foundation
import SwiftData

enum CaptchaType: String, Codable, CaseIterable {
    case math = "Math Problem"
    case nfc = "NFC Tag"
}

enum MathDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

@Model
final class AlarmModel {
    @Attribute(.unique) var id: UUID
    var label: String
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    var repeatDays: Set<Int> // Calendar weekday: 1=Sun..7=Sat, empty = one-time
    var captchaType: CaptchaType
    var mathDifficulty: MathDifficulty
    var nfcTagID: String?
    var snoozeDurationMinutes: Int
    var maxSnoozes: Int // 0 = unlimited, >0 = max snooze count
    var currentSnoozeCount: Int // Tracks how many times snoozed

    // Phase 4: Shortcuts integration
    var onFireShortcutName: String?
    var onDismissShortcutName: String?

    init(
        id: UUID = UUID(),
        label: String = "Alarm",
        hour: Int = 8,
        minute: Int = 0,
        isEnabled: Bool = true,
        repeatDays: Set<Int> = [],
        captchaType: CaptchaType = .math,
        mathDifficulty: MathDifficulty = .easy,
        nfcTagID: String? = nil,
        snoozeDurationMinutes: Int = 5,
        maxSnoozes: Int = 3,
        currentSnoozeCount: Int = 0
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.repeatDays = repeatDays
        self.captchaType = captchaType
        self.mathDifficulty = mathDifficulty
        self.nfcTagID = nfcTagID
        self.snoozeDurationMinutes = snoozeDurationMinutes
        self.maxSnoozes = maxSnoozes
        self.currentSnoozeCount = currentSnoozeCount
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatDaysString: String {
        if repeatDays.isEmpty { return "One-time" }
        let daySymbols = Calendar.current.shortWeekdaySymbols
        let sorted = repeatDays.sorted()
        if sorted == Array(2...6) { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        if sorted == Array(1...7) { return "Every day" }
        return sorted.map { daySymbols[$0 - 1] }.joined(separator: ", ")
    }

    /// Converts repeatDays to AlarmKit weekday values
    var alarmKitWeekdays: [Int] {
        // Calendar weekday values map directly
        Array(repeatDays).sorted()
    }
}
