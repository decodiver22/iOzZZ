//
//  iOzZZApp.swift
//  iOzZZ
//
//  App entry point and notification listener.
//  Shows captcha overlay when alarm dismissal is requested.
//  Coordinates snooze notifications and AlarmKit authorization.
//

import SwiftUI
import SwiftData

@main
struct iOzZZApp: App {
    @State private var captchaAlarmID: UUID?

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                // Captcha overlay - shown when user taps "Dismiss" on alarm
                if let alarmID = captchaAlarmID {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    CaptchaView(alarmID: alarmID) {
                        withAnimation {
                            captchaAlarmID = nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: captchaAlarmID)
            .task {
                let authorized = await AlarmService.shared.requestAuthorization()
                print("✅ AlarmKit authorization: \(authorized ? "granted" : "denied")")
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .dismissAlarmRequested)
            ) { notification in
                guard let idString = notification.userInfo?["alarmIdentifier"] as? String,
                      let uuid = UUID(uuidString: idString) else {
                    return
                }

                withAnimation {
                    captchaAlarmID = uuid
                }

                // Trigger fire shortcut if configured
                triggerFireShortcutIfNeeded(for: uuid)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .alarmSnoozed)
            ) { notification in
                guard let idString = notification.userInfo?["alarmIdentifier"] as? String,
                      let uuid = UUID(uuidString: idString) else {
                    return
                }

                handleSnooze(alarmID: uuid)
            }
        }
        .modelContainer(for: [AlarmModel.self, NFCTagModel.self])
    }

    private func triggerFireShortcutIfNeeded(for alarmID: UUID) {
        // Phase 4: Will look up alarm and trigger onFireShortcutName
        // For now this is a placeholder
    }

    private func handleSnooze(alarmID: UUID) {
        // This will be handled by ContentView which has model context access
        NotificationCenter.default.post(
            name: .handleSnoozeInApp,
            object: nil,
            userInfo: ["alarmIdentifier": alarmID.uuidString]
        )
    }
}
