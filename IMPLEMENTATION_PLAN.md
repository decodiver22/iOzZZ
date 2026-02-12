# iOzZZ - Comprehensive Implementation Plan (v2 + Agent Feedback)

**Date:** 2026-02-12
**Status:** Ready for Implementation
**Agent Team Review:** Complete (Architecture, API, Migration, UX)

---

## Executive Summary

This document synthesizes the v2 architectural plan with comprehensive agent feedback on the current implementation. The goal is a production-ready alarm app with captcha enforcement that users **cannot bypass**.

**Key Findings:**
- ✅ Current liquid glass UX is strong
- ❌ Critical captcha bypass vulnerability exists
- ⚠️ Manual snooze was deliberate (postAlert unreliable)
- ⚠️ No cross-process state persistence
- ⚠️ No SwiftData ↔ AlarmKit reconciliation

**Estimated Implementation:** 16-21 hours over 3-5 days

---

## Table of Contents

1. [Critical Vulnerabilities](#critical-vulnerabilities)
2. [Architecture Gap Analysis](#architecture-gap-analysis)
3. [AlarmKit API Reality Check](#alarmkit-api-reality-check)
4. [Migration Strategy (Phased)](#migration-strategy-phased)
5. [UX Design Improvements](#ux-design-improvements)
6. [Critical Decisions Required](#critical-decisions-required)
7. [Implementation Roadmap](#implementation-roadmap)

---

## Critical Vulnerabilities

### 1. Captcha Bypass via Force-Quit

**Threat:** User can silence alarm without solving captcha

**Attack Vector:**
1. Alarm fires → User taps "Turn Off" (DismissAlarmIntent)
2. App opens → Captcha shows
3. User force-quits app (swipe up in app switcher)
4. Alarm is silent, captcha not solved

**Root Cause:** `captchaAlarmID` is in-memory `@State` - lost on app termination

**Impact:** Core value proposition broken - app doesn't force wakeup

**Fix:** Persistent `pendingCaptchaAlarmID` in App Groups UserDefaults + recovery on app launch

---

### 2. Snooze State Lost on Crash

**Threat:** Snooze count lost if app crashes during snooze sequence

**Root Cause:** `currentSnoozeCount` in SwiftData (in-app only), not accessible from Intent extensions

**Impact:** Max snooze enforcement can be bypassed via repeated app restarts

**Fix:** Move snooze tracking to App Groups UserDefaults

---

### 3. SwiftData ↔ AlarmKit Drift

**Threat:** Database and AlarmKit schedules can become inconsistent

**Root Cause:** No reconciliation logic on app launch

**Impact:** Alarms may not fire despite being "enabled" in UI, or phantom alarms may fire

**Fix:** Add `reconcileAlarms()` on app launch that syncs both stores

---

## Architecture Gap Analysis

### Current Implementation vs v2 Requirements

| Component | Current Status | v2 Requirement | Gap | Priority |
|-----------|---------------|----------------|-----|----------|
| **Snooze Architecture** | ❌ Manual re-scheduling via NotificationCenter | AlarmKit postAlert native | **HIGH** - Replace or improve | P1 |
| **Cross-Process Storage** | ❌ SwiftData only | App Groups UserDefaults | **HIGH** - Missing | P0 |
| **Captcha Bypass Defense** | ❌ No recovery | pendingCaptchaAlarmID persistence | **CRITICAL** - Missing | P0 |
| **Reconciliation** | ❌ No sync logic | reconcileAlarms() on launch | **HIGH** - Missing | P1 |
| **Project Structure** | ⚠️ Flat | Organized folders | **LOW** - Refactor | P3 |
| **Recurring Alarms** | ✅ Working | Weekly recurrence | **COMPLETE** - None | - |
| **Snooze Limit Logic** | ⚠️ SwiftData only | App Groups tracking | **MEDIUM** - Storage wrong | P1 |

---

## AlarmKit API Reality Check

### v2 Plan Assumptions vs Actual API

#### ❌ Assumption 1: postAlert is Reliable
**v2 Plan Said:** Use AlarmKit's postAlert for native snooze re-fire

**Reality:** Code comment (AlarmService.swift, line 98):
```swift
// We don't use postAlert since we handle snooze manually
let countdownDuration = Alarm.CountdownDuration(
    preAlert: 1.0,
    postAlert: nil  // ← Deliberately avoided
)
```

**Why:** postAlert proved unreliable in testing. Manual snooze was a deliberate architectural choice.

**Decision Needed:** Test postAlert again (maybe iOS 26 fixed it?) or keep manual approach

---

#### ❌ Assumption 2: Can Remove Snooze Button Dynamically
**v2 Plan Said:** Remove snooze button after max snoozes reached

**Reality:** AlarmKit requires `stopButton` (snooze) always present. Can only customize `secondaryButton`.

**Current Workaround:** ✅ Enforce max snoozes by forcing captcha instead of snoozing (logic is correct)

---

#### ✅ Assumption 3: Recurring Alarms Supported
**v2 Plan Said:** Need to map repeatDays to AlarmKit

**Reality:** Already fully implemented (AlarmService.swift, lines 221-238):
```swift
let weekdays = alarm.repeatDays.sorted().compactMap { Locale.Weekday($0) }
let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(weekdays)
let relative = Alarm.Schedule.Relative(time: time, repeats: recurrence)
```

**Status:** ✅ Works correctly, no changes needed

---

#### ✅ Assumption 4: Can List Scheduled Alarms
**v2 Plan Said:** Need reconciliation API

**Reality:** `AlarmManager.shared.alarms` property exists (AlarmService.swift, line 195):
```swift
let alarms = try await manager.alarms
```

**Status:** ✅ Reconciliation is possible

---

### Critical Unanswered Question

**Does alarm audio continue after DismissAlarmIntent.perform() returns without calling stop()?**

**Test Required:**
1. Schedule alarm
2. Modify DismissAlarmIntent to return immediately (no stop() call)
3. Let alarm fire, tap "Turn Off"
4. **Observe:** Does alarm audio continue or stop?

**Impact on Architecture:**
- **If continues:** Current architecture is sound, just needs hardening
- **If stops:** Need URL scheme workaround or nag alarm fallback

---

## Migration Strategy (Phased)

### Phase 0: Critical Behavior Testing (2-3 hours)

**Goal:** Validate AlarmKit behavior before committing to architecture

**Tests Required:**

#### Test 1: Audio Behavior After Intent Return
```swift
// In DismissAlarmIntent.perform()
func perform() async throws -> some IntentResult {
    // DON'T call AlarmManager.shared.stop()
    // Just return immediately
    return .result()
}
```

**Observe:** Does alarm keep ringing?

---

#### Test 2: postAlert Reliability
```swift
// In AlarmService.scheduleAlarm()
let countdownDuration = Alarm.CountdownDuration(
    preAlert: 1.0,
    postAlert: 300  // 5 minutes
)
```

**Test:** Create alarm, snooze, verify re-fires exactly 5 minutes later. Repeat 5 times.

---

#### Test 3: App Groups from Intent Extension
```swift
// In SnoozeAlarmIntent.perform()
let defaults = UserDefaults(suiteName: "group.com.iozzz.shared")!
defaults.set(42, forKey: "test")
print("Wrote from Intent: 42")

// In app
let defaults = UserDefaults(suiteName: "group.com.iozzz.shared")!
let value = defaults.integer(forKey: "test")
print("Read in app: \(value)")
```

**Verify:** Value reads correctly across both contexts

---

### Phase 1: Foundation (Non-Breaking) (3-4 hours)

**Goal:** Add infrastructure without changing existing behavior

**Risk Level:** ✅ LOW

#### 1.1 Add App Groups Capability
**Files:** Project settings, Entitlements

```bash
# In Xcode:
# 1. Select target → Signing & Capabilities
# 2. Click + → App Groups
# 3. Add: group.com.iozzz.shared
```

**Testing:** Build succeeds, entitlements file created

---

#### 1.2 Create SnoozeTracker
**New File:** `iOzZZ/Services/SnoozeTracker.swift`

```swift
/// Cross-process snooze tracking using App Groups.
final class SnoozeTracker {
    private static let suiteName = "group.com.iozzz.shared"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }

    /// Increment snooze count (returns new count)
    static func incrementSnooze(for alarmID: UUID) -> Int {
        let key = "snooze_count_\(alarmID.uuidString)"
        let current = defaults.integer(forKey: key)
        let new = current + 1
        defaults.set(new, forKey: key)
        print("[SnoozeTracker] \(alarmID): \(current) → \(new)")
        return new
    }

    /// Get current snooze count
    static func getSnoozeCount(for alarmID: UUID) -> Int {
        let key = "snooze_count_\(alarmID.uuidString)"
        return defaults.integer(forKey: key)
    }

    /// Reset snooze count (after captcha success)
    static func resetSnooze(for alarmID: UUID) {
        let key = "snooze_count_\(alarmID.uuidString)"
        defaults.set(0, forKey: key)
        print("[SnoozeTracker] Reset \(alarmID)")
    }
}
```

---

#### 1.3 Create CaptchaTracker
**New File:** `iOzZZ/Services/CaptchaTracker.swift`

```swift
/// Tracks pending captcha state for recovery after force-quit.
final class CaptchaTracker {
    private static let suiteName = "group.com.iozzz.shared"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }
    private static let key = "pending_captcha_alarm_id"

    /// Mark alarm as requiring captcha
    static func setPendingCaptcha(for alarmID: UUID) {
        defaults.set(alarmID.uuidString, forKey: key)
        print("[CaptchaTracker] Pending: \(alarmID)")
    }

    /// Get pending captcha alarm (if any)
    static func getPendingCaptcha() -> UUID? {
        guard let str = defaults.string(forKey: key) else { return nil }
        return UUID(uuidString: str)
    }

    /// Clear pending captcha (after solve or cancel)
    static func clearPendingCaptcha() {
        defaults.removeObject(forKey: key)
        print("[CaptchaTracker] Cleared")
    }
}
```

---

#### 1.4 Add Parallel Tracking (Read-Only)
**Files to Modify:** ContentView.swift, CaptchaView.swift, DismissAlarmIntent.swift

```swift
// In ContentView.handleSnooze()
alarm.currentSnoozeCount += 1

// PHASE 1: Parallel tracking
let trackedCount = SnoozeTracker.incrementSnooze(for: alarmID)
if trackedCount != alarm.currentSnoozeCount {
    print("⚠️ MISMATCH: Tracker=\(trackedCount), Model=\(alarm.currentSnoozeCount)")
}
```

```swift
// In CaptchaView.dismissAlarm()
alarm.currentSnoozeCount = 0

// PHASE 1: Parallel tracking
SnoozeTracker.resetSnooze(for: alarmID)
```

```swift
// In DismissAlarmIntent.perform()
CaptchaTracker.setPendingCaptcha(for: uuid)

// Existing notification post...
```

---

#### 1.5 Add Launch Recovery Logging
**File:** iOzZZApp.swift

```swift
.task {
    let authorized = await AlarmService.shared.requestAuthorization()

    // PHASE 1: Check for pending captcha
    if let pendingID = CaptchaTracker.getPendingCaptcha() {
        print("⚠️ RECOVERY: Found pending captcha for \(pendingID)")
        // For now just log, Phase 3 will show UI
    }
}
```

**Testing:**
- Create alarm, snooze 3 times
- Check console logs - should see parallel counts match
- Trigger captcha, force-quit, relaunch
- Check console - should see "RECOVERY: Found pending captcha"

---

### Phase 2: Snooze Migration (3-4 hours)

**Goal:** Replace manual snooze or improve it

**Risk Level:** ⚠️ MEDIUM

**Prerequisite:** Phase 0 Test 2 confirms postAlert reliability

#### Option A: If postAlert Works

**Files to Modify:** AlarmService.swift, ContentView.swift

```swift
// In AlarmService.scheduleAlarm()
let countdownDuration = Alarm.CountdownDuration(
    preAlert: 1.0,
    postAlert: TimeInterval(alarm.snoozeDurationMinutes * 60)
)
```

**Remove:** Entire `AlarmService.snoozeAlarm()` method (no longer needed)

```swift
// In ContentView.handleSnooze()
private func handleSnooze(alarmID: UUID) {
    guard let alarm = alarms.first(where: { $0.id == alarmID }) else { return }

    alarm.currentSnoozeCount += 1
    SnoozeTracker.incrementSnooze(for: alarmID)

    if alarm.maxSnoozes > 0 && alarm.currentSnoozeCount >= alarm.maxSnoozes {
        // Force captcha
        NotificationCenter.default.post(...)
    } else {
        // DO NOTHING - postAlert handles re-fire
        print("✅ AlarmKit will re-fire via postAlert")
    }

    try? modelContext.save()
}
```

---

#### Option B: If postAlert Doesn't Work

**Keep manual snooze but improve error handling:**

```swift
func snoozeAlarm(_ alarm: AlarmModel) async throws {
    print("😴 Snoozing \(alarm.label) for \(alarm.snoozeDurationMinutes) min")

    // Cancel with explicit error handling
    do {
        try cancelAlarm(id: alarm.id)
    } catch {
        print("❌ Cancel failed: \(error)")
        throw SnoozeError.cancelFailed(error)
    }

    // Calculate snooze time
    guard let snoozeTime = Calendar.current.date(
        byAdding: .minute,
        value: alarm.snoozeDurationMinutes,
        to: Date()
    ) else {
        throw SnoozeError.invalidCalculation
    }

    let components = Calendar.current.dateComponents([.hour, .minute], from: snoozeTime)
    guard let hour = components.hour, let minute = components.minute else {
        throw SnoozeError.invalidComponents
    }

    // Temporarily update, schedule, restore
    let originalHour = alarm.hour
    let originalMinute = alarm.minute

    alarm.hour = hour
    alarm.minute = minute

    do {
        try await scheduleAlarm(alarm)
        alarm.hour = originalHour
        alarm.minute = originalMinute
        print("✅ Will re-fire at \(hour):\(String(format: "%02d", minute))")
    } catch {
        // CRITICAL: Restore even on failure
        alarm.hour = originalHour
        alarm.minute = originalMinute
        throw SnoozeError.scheduleFailed(error)
    }
}

enum SnoozeError: Error {
    case cancelFailed(Error)
    case invalidCalculation
    case invalidComponents
    case scheduleFailed(Error)
}
```

---

### Phase 3: Captcha Hardening (5-6 hours)

**Goal:** Eliminate captcha bypass vulnerabilities

**Risk Level:** ⚠️ MEDIUM

#### 3.1 Implement Captcha Recovery
**File:** iOzZZApp.swift

```swift
@main
struct iOzZZApp: App {
    @State private var captchaAlarmID: UUID?

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppGradient()
                    .ignoresSafeArea()

                ContentView()

                if let alarmID = captchaAlarmID {
                    // Captcha overlay...
                }
            }
            .task {
                let authorized = await AlarmService.shared.requestAuthorization()

                // PHASE 3: Recover pending captcha
                if let pendingID = CaptchaTracker.getPendingCaptcha() {
                    print("⚠️ RECOVERY: Restoring captcha for \(pendingID)")
                    await MainActor.run {
                        withAnimation {
                            captchaAlarmID = pendingID
                        }
                    }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .dismissAlarmRequested)
            ) { notification in
                guard let idString = notification.userInfo?["alarmIdentifier"] as? String,
                      let uuid = UUID(uuidString: idString) else { return }

                // Mark as pending BEFORE showing overlay
                CaptchaTracker.setPendingCaptcha(for: uuid)

                withAnimation {
                    captchaAlarmID = uuid
                }
            }
        }
    }
}
```

**Testing:**
1. Trigger alarm, tap "Dismiss"
2. Verify captcha shows
3. Force-quit app
4. Launch app manually
5. **Verify captcha overlay re-appears automatically**
6. Solve captcha
7. Verify alarm stops and overlay dismisses

---

#### 3.2 Move Snooze Enforcement to Intent Layer
**Files:** DismissAlarmIntent.swift, AlarmService.swift, ContentView.swift

```swift
// In SnoozeAlarmIntent.perform()
func perform() async throws -> some IntentResult {
    guard let uuid = UUID(uuidString: alarmIdentifier) else {
        return .result()
    }

    try? AlarmManager.shared.stop(id: uuid)

    // PHASE 3: Enforce limit in Intent
    let snoozeCount = SnoozeTracker.incrementSnooze(for: uuid)
    let maxSnoozes = getMaxSnoozes(for: uuid)

    if maxSnoozes > 0 && snoozeCount >= maxSnoozes {
        print("🚫 Max snoozes (\(maxSnoozes)) reached! Forcing captcha...")

        CaptchaTracker.setPendingCaptcha(for: uuid)
        NotificationCenter.default.post(
            name: .dismissAlarmRequested,
            object: nil,
            userInfo: ["alarmIdentifier": alarmIdentifier]
        )
    } else {
        print("✅ Snoozed (\(snoozeCount)/\(maxSnoozes))")
        NotificationCenter.default.post(
            name: .alarmSnoozed,
            object: nil,
            userInfo: ["alarmIdentifier": alarmIdentifier]
        )
    }

    return .result()
}

private func getMaxSnoozes(for alarmID: UUID) -> Int {
    let defaults = UserDefaults(suiteName: "group.com.iozzz.shared")!
    return defaults.integer(forKey: "max_snoozes_\(alarmID.uuidString)")
}
```

```swift
// In AlarmService.scheduleAlarm()
func scheduleAlarm(_ alarm: AlarmModel) async throws {
    // ... existing code ...

    // PHASE 3: Store maxSnoozes for Intent access
    let defaults = UserDefaults(suiteName: "group.com.iozzz.shared")!
    defaults.set(alarm.maxSnoozes, forKey: "max_snoozes_\(alarm.id.uuidString)")

    try await manager.schedule(id: id, configuration: config)
}
```

```swift
// In ContentView.handleSnooze()
private func handleSnooze(alarmID: UUID) {
    guard let alarm = alarms.first(where: { $0.id == alarmID }) else { return }

    // Sync count from App Groups (Intent already incremented)
    alarm.currentSnoozeCount = SnoozeTracker.getSnoozeCount(for: alarmID)

    // Check if captcha forced by Intent
    if CaptchaTracker.getPendingCaptcha() == alarmID {
        print("⚠️ Captcha forced by Intent layer")
        // Don't re-schedule
    } else {
        // Normal snooze
        Task {
            try? await AlarmService.shared.snoozeAlarm(alarm)
        }
    }

    try? modelContext.save()
}
```

---

#### 3.3 Optional: Nag Alarm Fallback
**New File:** `iOzZZ/Services/NagAlarmService.swift`

```swift
/// Aggressive fallback alarm if captcha bypassed.
final class NagAlarmService {
    static func scheduleNagAlarm(for alarmID: UUID) async throws {
        let nagID = UUID()
        let nagTime = Date().addingTimeInterval(5 * 60)  // 5 min from now

        let components = Calendar.current.dateComponents([.hour, .minute], from: nagTime)
        let time = Alarm.Schedule.Relative.Time(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: "⚠️ WAKE UP! Solve captcha to dismiss"),
            stopButton: nil,  // No snooze
            secondaryButton: AlarmButton(
                text: "Solve Captcha",
                textColor: .white,
                systemImageName: "exclamationmark.triangle.fill"
            ),
            secondaryButtonBehavior: .custom
        )

        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes<AlarmMetadataType>(
            presentation: presentation,
            metadata: AlarmMetadataType(alarmIdentifier: alarmID.uuidString),
            tintColor: .red
        )

        let countdown = Alarm.CountdownDuration(preAlert: 1.0, postAlert: 60)  // Re-fire every minute
        let schedule = Alarm.Schedule.relative(.init(time: time))
        let secondaryIntent = DismissAlarmIntent(alarmIdentifier: alarmID.uuidString)

        let config = AlarmManager.AlarmConfiguration<AlarmMetadataType>(
            countdownDuration: countdown,
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: secondaryIntent
        )

        try await AlarmManager.shared.schedule(id: nagID, configuration: config)

        // Store nag ID for cleanup
        let defaults = UserDefaults(suiteName: "group.com.iozzz.shared")!
        defaults.set(nagID.uuidString, forKey: "nag_alarm_\(alarmID.uuidString)")
    }

    static func cancelNagAlarm(for alarmID: UUID) throws {
        let defaults = UserDefaults(suiteName: "group.com.iozzz.shared")!
        guard let nagIDString = defaults.string(forKey: "nag_alarm_\(alarmID.uuidString)"),
              let nagID = UUID(uuidString: nagIDString) else { return }

        try AlarmManager.shared.cancel(id: nagID)
        defaults.removeObject(forKey: "nag_alarm_\(alarmID.uuidString)")
    }
}
```

**Usage:**
```swift
// In DismissAlarmIntent.perform()
CaptchaTracker.setPendingCaptcha(for: uuid)
try? await NagAlarmService.scheduleNagAlarm(for: uuid)

// In CaptchaView.dismissAlarm()
try? NagAlarmService.cancelNagAlarm(for: alarmID)
```

---

### Phase 4: Polish & Restructuring (3-4 hours)

**Goal:** Clean up code organization, add tests

**Risk Level:** ✅ LOW

#### 4.1 Folder Restructuring

**Target Structure:**
```
iOzZZ/
├── App/
│   ├── iOzZZApp.swift
│   ├── ContentView.swift
│   └── AppGradient.swift (NEW)
├── Models/
│   ├── AlarmModel.swift
│   ├── NFCTagModel.swift
│   └── AlarmMetadataType.swift
├── Services/
│   ├── AlarmService.swift
│   ├── CaptchaService.swift
│   ├── NFCService.swift
│   ├── SnoozeTracker.swift (NEW)
│   ├── CaptchaTracker.swift (NEW)
│   └── NagAlarmService.swift (NEW, optional)
├── Views/
│   ├── Alarms/
│   │   ├── AlarmListView.swift
│   │   └── AlarmEditView.swift
│   ├── Captcha/
│   │   ├── CaptchaView.swift
│   │   ├── MathCaptchaView.swift
│   │   └── NFCCaptchaView.swift
│   └── NFC/
│       └── NFCRegistrationView.swift
├── Intents/
│   └── DismissAlarmIntent.swift
├── Utilities/
│   ├── Notifications.swift
│   └── Extensions.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

**Migration:** Create folders, move files one at a time, build after each

---

#### 4.2 Add Test Coverage

**New Files:**
- `iOzZZTests/SnoozeTrackerTests.swift`
- `iOzZZTests/CaptchaTrackerTests.swift`

```swift
// SnoozeTrackerTests.swift
import Testing
@testable import iOzZZ

struct SnoozeTrackerTests {
    @Test func testIncrementAndReset() {
        let alarmID = UUID()

        let count1 = SnoozeTracker.incrementSnooze(for: alarmID)
        #expect(count1 == 1)

        let count2 = SnoozeTracker.incrementSnooze(for: alarmID)
        #expect(count2 == 2)

        SnoozeTracker.resetSnooze(for: alarmID)
        let count3 = SnoozeTracker.getSnoozeCount(for: alarmID)
        #expect(count3 == 0)
    }
}
```

---

#### 4.3 Fix Recurring Alarm Re-scheduling

**File:** CaptchaView.swift

```swift
private func dismissAlarm() {
    try? AlarmService.shared.stopAlarm(id: alarmID)

    if let alarm = alarm {
        alarm.currentSnoozeCount = 0
        SnoozeTracker.resetSnooze(for: alarmID)

        // PHASE 4: Re-schedule recurring alarms
        if !alarm.repeatDays.isEmpty && alarm.isEnabled {
            Task {
                try? await AlarmService.shared.scheduleAlarm(alarm)
                print("✅ Recurring alarm re-scheduled")
            }
        }
    }

    try? NagAlarmService.cancelNagAlarm(for: alarmID)
    CaptchaTracker.clearPendingCaptcha()

    onDismissed()
}
```

---

## UX Design Improvements

### Current Strengths ✅

1. **Premium Liquid Glass Aesthetic** - ultraThinMaterial with gradient overlays
2. **Excellent Typography Hierarchy** - 48pt time, clear labels
3. **Sophisticated Color Palette** - Dark blue to black gradient
4. **Thoughtful Microinteractions** - Toggle switches, badges

### Critical UX Fixes

#### Fix 1: Delete Button Too Tall (HIGH)
**Current:** `.padding(.vertical, 12)` - oversized
**Fix:** Reduce to `.padding(.vertical, 10)` or move to toolbar

```swift
// Option A: Move to toolbar (preferred)
.toolbar {
    ToolbarItem(placement: .destructiveAction) {
        Button("Delete", role: .destructive) { deleteAlarm() }
    }
}

// Option B: Reduce padding
.padding(.vertical, 10)  // Reduced from 12
```

---

#### Fix 2: Form Styling Inconsistent (HIGH)
**Current:** Generic iOS Form with system backgrounds
**Fix:** Add gradient background

```swift
Form {
    // ... sections ...
}
.scrollContentBackground(.hidden)
.background(
    LinearGradient(
        colors: [Color(red: 0.08, green: 0.08, blue: 0.20), Color.black],
        startPoint: .top,
        endPoint: .bottom
    )
    .ignoresSafeArea()
)
```

---

#### Fix 3: NFC Captcha Not Styled (MEDIUM)
**Current:** `.borderedProminent` (generic system button)
**Fix:** Apply glass styling

```swift
Button {
    startScan()
} label: {
    Label(
        nfcService.isScanning ? "Scanning..." : "Start NFC Scan",
        systemImage: "wave.3.right"
    )
    .font(.headline)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .background(
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .opacity(0.8)

            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    )
}
```

---

#### Fix 4: Empty State Font Oversized (MEDIUM)
**Current:** 32pt title (larger than 48pt alarm time - confusing)
**Fix:** Reduce to 28pt

```swift
Text("No Alarms")
    .font(.system(size: 28, weight: .bold, design: .rounded))  // Reduced from 32
```

---

### Enhancement Opportunities

#### 1. Haptic Feedback
```swift
// In AlarmRow toggle
.onChange(of: alarm.isEnabled) { _, newValue in
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    // ... handler ...
}

// In MathCaptchaView
private func checkAnswer() {
    if CaptchaService.validate(...) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    } else {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

---

#### 2. Reusable Glass Card Component
```swift
struct GlassCard: ViewModifier {
    let opacity: Double
    let cornerRadius: Double

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(opacity)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 15, y: 8)
            .shadow(color: .blue.opacity(0.2), radius: 20, y: 10)
    }
}

extension View {
    func glassCard(opacity: Double = 0.6, cornerRadius: Double = 24) -> some View {
        modifier(GlassCard(opacity: opacity, cornerRadius: cornerRadius))
    }
}
```

**Usage:** `.glassCard()`

---

### Design System Reference

**Colors:**
```
Background: LinearGradient([rgb(0.08, 0.08, 0.20), .black])
Glass Base: .ultraThinMaterial, opacity: 0.6
Inner Glow: white.opacity(0.15) → 0.05
Border: white.opacity(0.3) → 0.1
Text Primary: .white
Text Secondary: .white.opacity(0.7)
Success: .green
Error: .red
```

**Typography:**
```
Display Time: 48pt, thin, monospacedDigit
Headers: 16pt, semibold
Body: 16pt, regular
Labels: 14pt, semibold
Captions: 12pt, medium
```

**Spacing:**
```
Card Padding: 20pt
Corner Radius: 24pt (cards), 14pt (buttons), 12pt (badges)
List Spacing: 16pt
Button Height: 16pt vertical padding
```

---

## Critical Decisions Required

### Decision 1: Alarm Audio Behavior (BLOCKING)

**Test Required:** Does alarm audio continue after DismissAlarmIntent returns without `stop()`?

**If YES:** ✅ Current architecture is sound
**If NO:** ⚠️ Need URL scheme workaround or nag alarm

**Action:** Run Phase 0 Test 1 immediately

---

### Decision 2: postAlert vs Manual Snooze

**Question:** Is postAlert reliable on iOS 26?

**Current:** Deliberately avoided (comment: "proved unreliable")

**Options:**
- A) Test again - maybe iOS 26 fixed it
- B) Keep manual snooze with improved error handling
- C) Hybrid approach

**Recommendation:** Test Phase 0 Test 2, decide based on results

---

### Decision 3: Nag Alarm - Yes or No?

**Question:** Is aggressive re-firing alarm acceptable UX?

**Pro:** Forces captcha completion
**Con:** Could anger users

**Recommendation:** Skip initially, add if Phase 0 Test 1 shows alarm stops automatically

---

## Implementation Roadmap

### Week 1: Foundation + Critical Fixes

**Day 1-2: Phase 0 Testing**
- [ ] Test alarm audio behavior
- [ ] Test postAlert reliability
- [ ] Test App Groups from Intent

**Day 3-4: Phase 1 + Critical UX**
- [ ] Add App Groups capability
- [ ] Create SnoozeTracker + CaptchaTracker
- [ ] Add parallel tracking
- [ ] Fix delete button sizing
- [ ] Fix form styling

**Day 5: Phase 3.1**
- [ ] Implement captcha recovery on launch
- [ ] Test force-quit bypass defense

---

### Week 2: Complete Migration

**Day 6-7: Phase 2**
- [ ] Decide snooze approach (postAlert vs manual)
- [ ] Implement chosen approach
- [ ] Test snooze reliability

**Day 8-9: Phase 3.2**
- [ ] Move snooze enforcement to Intent layer
- [ ] Store maxSnoozes in App Groups
- [ ] Test max snooze limit from Intent

**Day 10: Phase 4**
- [ ] Folder restructuring
- [ ] Add test coverage
- [ ] Fix recurring alarm re-scheduling

---

### Week 3: Polish + Verification

**Day 11-12: UX Enhancements**
- [ ] Add haptic feedback
- [ ] Create glass card component
- [ ] Add captcha success animation

**Day 13-14: Testing**
- [ ] Run all unit tests
- [ ] Manual testing on device
- [ ] Verify all scenarios

**Day 15: Documentation**
- [ ] Update README
- [ ] Document architecture decisions
- [ ] Create testing guide

---

## Success Criteria

### Must Have (Production Blocker)
- [ ] User CANNOT bypass captcha via force-quit
- [ ] User CANNOT bypass snooze limit
- [ ] SwiftData ↔ AlarmKit stay in sync
- [ ] Snooze state survives app crashes
- [ ] All alarms fire reliably

### Should Have (Quality)
- [ ] Consistent liquid glass aesthetic
- [ ] Haptic feedback on interactions
- [ ] Professional error handling
- [ ] Comprehensive test coverage

### Nice to Have (Polish)
- [ ] Organized folder structure
- [ ] Captcha success animation
- [ ] Dynamic Type support
- [ ] Accessibility labels

---

## Risk Mitigation

### If Phase 0 reveals alarm stops automatically:
**Workaround:** Use URL scheme instead of `openAppWhenRun`
```swift
// In AlarmService
let urlString = "iozzz://dismiss?alarm=\(alarm.id.uuidString)"
// Use custom URL handling instead of LiveActivityIntent
```

---

### If App Groups don't work in Intents:
**Workaround:** Pass maxSnoozes as Intent parameter
```swift
struct SnoozeAlarmIntent: LiveActivityIntent {
    var alarmIdentifier: String
    var maxSnoozes: Int  // Pass during scheduling
}
```

---

### If postAlert is still unreliable:
**Solution:** Keep manual snooze, add Phase 2 Option B error handling

---

## Appendix: Agent Team Contributions

- **Architecture Gap Agent:** Identified 4 critical missing features, 3 partial implementations
- **AlarmKit API Agent:** Verified recurring works, postAlert deliberately avoided, reconciliation possible
- **Migration Strategy Agent:** Designed 4-phase approach with risk levels and rollback plans
- **UX Design Agent:** Found 4 critical UX issues, provided design system, code-level fixes

---

**End of Implementation Plan**
