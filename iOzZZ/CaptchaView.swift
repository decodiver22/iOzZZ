//
//  CaptchaView.swift
//  iOzZZ
//
//  Router view that displays the appropriate captcha based on alarm configuration.
//  Handles alarm dismissal after successful captcha solve and snooze count reset.
//

import SwiftUI
import SwiftData

/// Router view: shows the correct captcha type based on the alarm's configuration.
struct CaptchaView: View {
    let alarmID: UUID
    let onDismissed: () -> Void

    @Query private var alarms: [AlarmModel]

    private var alarm: AlarmModel? {
        alarms.first { $0.id == alarmID }
    }

    var body: some View {
        Group {
            if let alarm {
                switch alarm.captchaType {
                case .math:
                    MathCaptchaView(
                        difficulty: alarm.mathDifficulty,
                        onSolved: { dismissAlarm() }
                    )
                case .nfc:
                    NFCCaptchaView(
                        expectedTagID: alarm.nfcTagID ?? "",
                        onSolved: { dismissAlarm() }
                    )
                }
            } else {
                // Alarm not found in SwiftData - allow dismissal
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Alarm not found")
                    Button("Dismiss") { dismissAlarm() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func dismissAlarm() {
        // Stop the alarm in AlarmKit
        try? AlarmService.shared.stopAlarm(id: alarmID)

        // Reset snooze count (captcha solved successfully)
        if let alarm = alarm {
            alarm.currentSnoozeCount = 0
            print("✅ Captcha solved! Snooze count reset for alarm: \(alarm.label)")
        }

        // Trigger dismiss shortcut if configured
        if let shortcutName = alarm?.onDismissShortcutName, !shortcutName.isEmpty {
            triggerShortcut(named: shortcutName)
        }

        onDismissed()
    }

    private func triggerShortcut(named name: String) {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}
