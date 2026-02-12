//
//  Notifications.swift
//  iOzZZ
//
//  Centralized notification names used throughout the app for alarm events.
//

import Foundation

extension Notification.Name {
    /// Posted by DismissAlarmIntent when user taps "Dismiss" button on alarm.
    /// Triggers the captcha overlay to be shown.
    /// UserInfo contains: ["alarmIdentifier": String]
    static let dismissAlarmRequested = Notification.Name("dismissAlarmRequested")

    /// Posted by SnoozeAlarmIntent when user taps "Snooze" button on alarm.
    /// Triggers snooze tracking and limit enforcement.
    /// UserInfo contains: ["alarmIdentifier": String]
    static let alarmSnoozed = Notification.Name("alarmSnoozed")

    /// Internal notification for delegating snooze handling to ContentView.
    /// This allows access to ModelContext for snooze count updates.
    /// UserInfo contains: ["alarmIdentifier": String]
    static let handleSnoozeInApp = Notification.Name("handleSnoozeInApp")
}
