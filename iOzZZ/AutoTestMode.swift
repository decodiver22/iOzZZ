import SwiftUI
import SwiftData

/// Automatic testing mode - creates test alarm and monitors for firing
@MainActor
class AutoTestMode: ObservableObject {
    static let shared = AutoTestMode()

    @Published var isTestRunning = false
    @Published var testStatus = ""
    @Published var testAlarmID: UUID?

    private var testStartTime: Date?
    private var checkTimer: Timer?

    private init() {}

    func startAutoTest(modelContext: ModelContext) {
        guard !isTestRunning else { return }

        print("🤖 AUTO TEST MODE STARTED")
        print(String(repeating: "=", count: 50))

        isTestRunning = true
        testStatus = "Creating test alarm..."
        testStartTime = Date()

        // Create test alarm for 90 seconds from now
        let now = Date()
        let future = Calendar.current.date(byAdding: .second, value: 90, to: now)!
        let components = Calendar.current.dateComponents([.hour, .minute], from: future)

        let testAlarm = AlarmModel(
            label: "🤖 Auto Test",
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            repeatDays: [],
            captchaType: .math,
            mathDifficulty: .easy,
            snoozeDurationMinutes: 1
        )

        testAlarmID = testAlarm.id
        modelContext.insert(testAlarm)
        try? modelContext.save()

        print("✅ Test alarm created: \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
        print("🔍 Alarm ID: \(testAlarm.id)")

        // Schedule the alarm
        Task {
            do {
                try await AlarmService.shared.scheduleAlarm(testAlarm)
                await MainActor.run {
                    testStatus = "Waiting for alarm to fire (90 seconds)..."
                    startMonitoring()
                }
            } catch {
                print("❌ Failed to schedule test alarm: \(error)")
                await MainActor.run {
                    testStatus = "Failed to schedule: \(error.localizedDescription)"
                    isTestRunning = false
                }
            }
        }
    }

    private func startMonitoring() {
        print("👀 Starting to monitor for alarm firing...")

        // Check every 5 seconds
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.testStartTime else { return }

                let elapsed = Date().timeIntervalSince(startTime)
                let remaining = 90 - Int(elapsed)

                if remaining > 0 {
                    self.testStatus = "Waiting... \(remaining) seconds until alarm should fire"
                    print("⏱️ \(remaining) seconds remaining...")
                } else if elapsed < 120 {
                    self.testStatus = "Alarm should have fired! Checking..."
                    print("🔔 Alarm should have fired by now...")
                } else {
                    self.testStatus = "Test timeout - alarm did not fire"
                    print("❌ TEST FAILED: Alarm did not fire within 120 seconds")
                    self.stopTest()
                }
            }
        }
    }

    func stopTest() {
        checkTimer?.invalidate()
        checkTimer = nil
        isTestRunning = false
        print("🛑 Auto test stopped")
    }

    func reportAlarmFired() {
        guard isTestRunning else { return }

        let elapsed = Date().timeIntervalSince(testStartTime ?? Date())
        print("✅ ALARM FIRED! Elapsed time: \(Int(elapsed)) seconds")
        testStatus = "✅ Alarm fired after \(Int(elapsed))s"
    }

    func reportCaptchaShown() {
        guard isTestRunning else { return }

        print("✅ CAPTCHA APPEARED!")
        testStatus = "✅ Captcha shown - test successful!"

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.stopTest()
        }
    }
}
