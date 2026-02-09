import Testing
@testable import iOzZZ

struct AlarmModelTests {

    @Test func defaultValues() {
        let alarm = AlarmModel()
        #expect(alarm.label == "Alarm")
        #expect(alarm.hour == 8)
        #expect(alarm.minute == 0)
        #expect(alarm.isEnabled == true)
        #expect(alarm.repeatDays.isEmpty)
        #expect(alarm.captchaType == .math)
        #expect(alarm.mathDifficulty == .easy)
        #expect(alarm.nfcTagID == nil)
        #expect(alarm.snoozeDurationMinutes == 5)
    }

    @Test func timeStringFormatsCorrectly() {
        let alarm = AlarmModel(hour: 7, minute: 5)
        #expect(alarm.timeString == "07:05")

        let alarm2 = AlarmModel(hour: 23, minute: 59)
        #expect(alarm2.timeString == "23:59")

        let alarm3 = AlarmModel(hour: 0, minute: 0)
        #expect(alarm3.timeString == "00:00")
    }

    @Test func repeatDaysStringOneTime() {
        let alarm = AlarmModel(repeatDays: [])
        #expect(alarm.repeatDaysString == "One-time")
    }

    @Test func repeatDaysStringWeekdays() {
        let alarm = AlarmModel(repeatDays: [2, 3, 4, 5, 6])
        #expect(alarm.repeatDaysString == "Weekdays")
    }

    @Test func repeatDaysStringWeekends() {
        let alarm = AlarmModel(repeatDays: [1, 7])
        #expect(alarm.repeatDaysString == "Weekends")
    }

    @Test func repeatDaysStringEveryDay() {
        let alarm = AlarmModel(repeatDays: [1, 2, 3, 4, 5, 6, 7])
        #expect(alarm.repeatDaysString == "Every day")
    }

    @Test func repeatDaysStringCustom() {
        let alarm = AlarmModel(repeatDays: [2, 4, 6]) // Mon, Wed, Fri
        let result = alarm.repeatDaysString
        // Should contain the short weekday symbols for Mon, Wed, Fri
        #expect(!result.isEmpty)
        #expect(result != "One-time")
        #expect(result != "Weekdays")
        #expect(result != "Weekends")
        #expect(result != "Every day")
    }

    @Test func captchaTypeRawValues() {
        #expect(CaptchaType.math.rawValue == "Math Problem")
        #expect(CaptchaType.nfc.rawValue == "NFC Tag")
    }

    @Test func mathDifficultyRawValues() {
        #expect(MathDifficulty.easy.rawValue == "Easy")
        #expect(MathDifficulty.medium.rawValue == "Medium")
        #expect(MathDifficulty.hard.rawValue == "Hard")
    }

    @Test func customInit() {
        let alarm = AlarmModel(
            label: "Morning",
            hour: 6,
            minute: 30,
            isEnabled: false,
            repeatDays: [2, 3, 4, 5, 6],
            captchaType: .nfc,
            mathDifficulty: .hard,
            nfcTagID: "04:A2:3B",
            snoozeDurationMinutes: 10
        )
        #expect(alarm.label == "Morning")
        #expect(alarm.hour == 6)
        #expect(alarm.minute == 30)
        #expect(alarm.isEnabled == false)
        #expect(alarm.repeatDays == [2, 3, 4, 5, 6])
        #expect(alarm.captchaType == .nfc)
        #expect(alarm.mathDifficulty == .hard)
        #expect(alarm.nfcTagID == "04:A2:3B")
        #expect(alarm.snoozeDurationMinutes == 10)
    }
}
