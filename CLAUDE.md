# iOzZZ - Project Guide for Claude

## Project Overview

**iOzZZ** is an iOS alarm app (iOS 26+) that enforces waking up by requiring the user to solve a captcha (math problem or NFC tag scan) to dismiss the alarm. Built with SwiftUI, AlarmKit, and SwiftData.

**Key Differentiator:** Unlike standard alarm apps, snoozing is free but dismissing requires solving a challenge. Users can configure max snooze limits to prevent infinite snoozing.

**Tech Stack:**
- Swift 6 / SwiftUI
- AlarmKit (iOS 26+) - System alarm scheduling
- SwiftData - Persistence
- Core NFC - NFC tag scanning
- App Intents - Custom Live Activity buttons

**Current Status:** Phases 1-3 complete (basic alarms, math captcha, NFC captcha). Phase 4 (Shortcuts integration) has placeholder fields but is not wired up.

---

## Architecture

### Core Pattern: AlarmKit + Captcha Integration

```
Alarm fires → System shows Lock Screen UI
  ├── "Snooze" (stop button) → SnoozeAlarmIntent
  │     → Increments snooze count
  │     → If max reached: Force captcha
  │     → Else: Re-schedule alarm for X minutes later
  │
  └── "Dismiss" (secondary button) → DismissAlarmIntent
        → Opens app (openAppWhenRun=true)
        → Shows captcha overlay
        → On success: AlarmManager.stop(id:)
```

**Critical Insight:** AlarmKit's stop button *always* stops the alarm, so we use it for "Snooze" and handle re-scheduling manually. The secondary button (our "Dismiss") uses `LiveActivityIntent.openAppWhenRun = true` to launch the app for captcha.

### Key Design Decisions

1. **AlarmKit alarm ID = SwiftData model ID**
   - Same UUID bridges both systems
   - Allows alarm lookup from intents
   - Simplifies deletion and cancellation

2. **Manual snooze re-scheduling**
   - AlarmKit's `postAlert` duration proved unreliable
   - We cancel and re-schedule alarms manually
   - See `AlarmService.snoozeAlarm()` for implementation

3. **Notification-based communication**
   - Intents post NotificationCenter events
   - App listens and shows UI
   - See `Notifications.swift` for all notification names

4. **Snooze count stored in model**
   - Tracked in `AlarmModel.currentSnoozeCount`
   - Reset on captcha success
   - Persisted with SwiftData

---

## File Structure

### Core Services
- `AlarmService.swift` - AlarmKit wrapper (schedule, cancel, stop, snooze)
- `CaptchaService.swift` - Pure math logic (stateless, no dependencies)
- `NFCService.swift` - NFC tag scanning (needs NSObject for delegate)
- `Notifications.swift` - Centralized notification names

### Data Models
- `AlarmModel.swift` - SwiftData model for alarms
- `NFCTagModel.swift` - SwiftData model for registered NFC tags
- `AlarmMetadataType.swift` - AlarmKit metadata wrapper

### Views
- `iOzZZApp.swift` - Entry point, captcha overlay, notification listeners
- `ContentView.swift` - Root navigation, snooze handling
- `AlarmListView.swift` - Main list with liquid glass cards
- `AlarmEditView.swift` - Create/edit alarm form
- `CaptchaView.swift` - Router (math vs NFC)
- `MathCaptchaView.swift` - Math problem UI
- `NFCCaptchaView.swift` - NFC scan prompt
- `NFCRegistrationView.swift` - Register NFC tags

### Debug Tools (DEBUG only)
- `AutoTestMode.swift` - Automated alarm testing
- `DebugMenuView.swift` - Manual testing menu (triple-tap to open)

### Utilities
- `Extensions.swift` - Date and Int helpers
- `LiquidGlassCard.swift` - Reusable glassmorphic UI component

### Intents
- `DismissAlarmIntent.swift` - Contains both DismissAlarmIntent and SnoozeAlarmIntent

---

## AlarmKit Integration

### Authorization
```swift
// Request once at app launch
await AlarmService.shared.requestAuthorization()
```

### Scheduling an Alarm
```swift
// Schedule (or re-schedule if already scheduled)
try await AlarmService.shared.scheduleAlarm(alarm)
```

**How it works:**
1. Builds `Alarm.Schedule.Relative` from hour/minute
2. For recurring alarms: converts repeatDays to weekly recurrence
3. Creates `AlarmAttributes` with presentation and metadata
4. Configures stop button (Snooze) and secondary button (Dismiss)
5. Sets countdown duration (preAlert: nil, postAlert: nil)
6. Calls `AlarmManager.shared.schedule(id:configuration:)`

### Stopping an Alarm
```swift
// Permanent stop (after captcha success)
try AlarmService.shared.stopAlarm(id: alarmID)
```

### Canceling an Alarm
```swift
// Remove from AlarmKit (when deleting or disabling)
try AlarmService.shared.cancelAlarm(id: alarm.id)
```

### Snooze Re-scheduling
```swift
// Manual re-schedule for snooze
try await AlarmService.shared.snoozeAlarm(alarm)
```

**Implementation:**
1. Cancel current alarm
2. Calculate snooze time (now + X minutes)
3. Temporarily update alarm.hour/minute to snooze time
4. Re-schedule alarm
5. Restore original hour/minute (for display)

**Why manual?** AlarmKit's `postAlert` duration is unreliable. Manual re-scheduling gives us full control and integrates with max snooze limits.

---

## Max Snooze Limit System

**Purpose:** Prevent infinite snoozing by forcing captcha after N snoozes.

**Flow:**
1. User taps "Snooze" → SnoozeAlarmIntent posts `.alarmSnoozed` notification
2. App increments `alarm.currentSnoozeCount`
3. Check limit:
   - If `currentSnoozeCount >= maxSnoozes`: Post `.dismissAlarmRequested` (force captcha)
   - Else: Call `AlarmService.snoozeAlarm()` (re-schedule)
4. On captcha success: Reset `currentSnoozeCount = 0`

**Configuration:**
- `maxSnoozes = 0` → Unlimited snoozing
- `maxSnoozes > 0` → Limit enforced

**Example:** maxSnoozes = 3, snoozeDuration = 5 min
- Snooze 1: +5 min (2 remaining)
- Snooze 2: +5 min (1 remaining)
- Snooze 3: +5 min (0 remaining)
- Snooze 4: Captcha forced!

---

## Testing

### Automated Tests
```bash
# Run unit tests
CMD+U in Xcode
```

- `CaptchaServiceTests` - Math problem generation and validation
- `AlarmModelTests` - Model helpers and defaults

### Manual Testing in Simulator

**Limitation:** AlarmKit Live Activity buttons (Snooze/Dismiss) **DO NOT render in simulator**. You'll see a basic notification banner without interactive buttons.

**Workaround:**
1. Triple-tap anywhere in the app to open Debug Menu
2. Use "Simulate Alarm Dismiss" to manually trigger captcha
3. Use "Create Test Alarm" to create alarm 90 seconds in future
4. Use "Check AlarmKit Status" to verify scheduling

### Manual Testing on Device

**Required:** Physical iOS 26+ device with Xcode 16 beta

**Full flow:**
1. Create alarm for 1 minute in future
2. Lock device
3. Wait for alarm to fire
4. Verify "Snooze" and "Dismiss" buttons appear
5. Test snooze limit enforcement
6. Test captcha solving

---

## Common Tasks

### Add a New Alarm
```swift
let alarm = AlarmModel(
    label: "Morning",
    hour: 8,
    minute: 0,
    repeatDays: [2,3,4,5,6], // Mon-Fri
    captchaType: .math,
    mathDifficulty: .medium,
    maxSnoozes: 3
)
modelContext.insert(alarm)
try await AlarmService.shared.scheduleAlarm(alarm)
```

### Delete an Alarm
```swift
// 1. Cancel in AlarmKit
try? AlarmService.shared.cancelAlarm(id: alarm.id)

// 2. Delete from SwiftData
modelContext.delete(alarm)
```

**Important:** Always cancel in AlarmKit BEFORE deleting from SwiftData.

### Update an Alarm
```swift
alarm.hour = 9
alarm.minute = 30

// If alarm is enabled, re-schedule
if alarm.isEnabled {
    try? AlarmService.shared.cancelAlarm(id: alarm.id)
    try? await AlarmService.shared.scheduleAlarm(alarm)
}
```

### Register an NFC Tag
```swift
// Show registration view
.sheet(isPresented: $showingNFCRegistration) {
    NFCRegistrationView { tagID in
        // Save to alarm config
        alarm.nfcTagID = tagID
    }
}
```

### Add a New Notification Type
```swift
// 1. Add to Notifications.swift
extension Notification.Name {
    static let myNewNotification = Notification.Name("myNewNotification")
}

// 2. Post it
NotificationCenter.default.post(
    name: .myNewNotification,
    object: nil,
    userInfo: ["key": "value"]
)

// 3. Listen for it
.onReceive(NotificationCenter.default.publisher(for: .myNewNotification)) { notification in
    // Handle it
}
```

---

## Important Gotchas

### 1. Swift 6 Concurrency
- All `AlarmService` methods are `@MainActor`
- `AlarmMetadataType` must be `nonisolated`
- Use `nonisolated(unsafe)` for `AlarmManager.shared` property

### 2. AlarmKit Requires iOS 26+
- Project won't build with older deployment targets
- Requires Xcode 16 beta
- Device testing requires iOS 26 beta

### 3. NFC Only Works on Physical Devices
- Simulator uses mock implementation (`#if targetEnvironment(simulator)`)
- Real NFC scanning requires device with NFC capability
- Must have `NFCReaderUsageDescription` in Info.plist

### 4. Live Activity Buttons Only on Device
- Simulator shows basic notifications without buttons
- Can't test full alarm flow in simulator
- Use Debug Menu for simulator testing

### 5. SwiftData Model IDs
- AlarmKit and SwiftData share the same UUID
- **Never** change alarm.id after scheduling
- Deleting alarm without canceling leaves orphan in AlarmKit

### 6. Snooze Re-scheduling Side Effects
- Temporarily modifies alarm.hour/minute during re-schedule
- Always restore original values after
- Don't save model context during snooze re-schedule

### 7. Notification Names
- All notification names centralized in `Notifications.swift`
- Don't define new `Notification.Name` extensions elsewhere
- Always document userInfo keys in comments

### 8. AlarmKit Recurrence
- Use `Locale.Weekday` not `Calendar.Component.weekday`
- Extension in AlarmService.swift maps Calendar → Locale.Weekday
- Sunday = 1 in Calendar, but Sunday = .sunday in Locale

---

## UX Design System

### Liquid Glass Effects
- Frosted `.ultraThinMaterial` backgrounds
- White gradient overlays (15% → 5% opacity)
- Border gradients with glow
- Multi-layer shadows (dark + colored)
- Use `LiquidGlassCard` component for consistency

### Typography Scale
- Alarm time: 72pt thin rounded
- Empty state icon: 120pt
- Math problem: 80pt semibold rounded
- Section headers: title3 semibold
- Body text: callout medium

### Spacing
- Card padding: 28px
- Card spacing: 24px
- Section gaps: 20px-32px
- Button padding: 18-24px vertical

### Colors
- Backgrounds: Dark gradient (navy → black)
- Text: White with opacity variants
- Accents: Green (enabled), Red (destructive), Blue (info)
- Glass tint: White 15%-30% opacity

---

## Build and Run

### Requirements
- Xcode 16 beta or later
- macOS 15 (Sequoia) or later
- iOS 26 SDK

### First Build
```bash
# Open project
open iOzZZ.xcodeproj

# Select iOS Simulator or Device
# CMD+B to build
# CMD+R to run
```

### Known Build Issues
- **AppIntentsSSUTraining error** on device builds (iOS beta issue)
- Workaround: Use simulator for development
- Full testing requires physical device

### Entitlements Needed
- AlarmKit usage
- NFC tag reading (device only)

### Info.plist Keys
- `NSAlarmKitUsageDescription` - "We need access to alarms to schedule your wake-up alarms"
- `NFCReaderUsageDescription` - "We need NFC to scan tags for alarm dismissal"

---

## Code Style

### Patterns to Follow
- `@Observable` for services (modern, no NSObject needed)
- `@MainActor` for UI-related services
- `nonisolated` for AlarmKit conformance
- Clear separation of concerns (Service ↔ Model ↔ View)
- Pure functions for business logic (see CaptchaService)

### Naming Conventions
- Services: `XService` (e.g., AlarmService, NFCService)
- Models: `XModel` (e.g., AlarmModel, NFCTagModel)
- Views: `XView` (e.g., CaptchaView, AlarmListView)
- Intents: `XIntent` (e.g., DismissAlarmIntent)

### Comments
- File headers: Purpose and key responsibilities
- Complex logic: Inline documentation with step-by-step breakdown
- Public APIs: DocC-style comments with parameters and returns
- Don't comment obvious code

### Error Handling
- Use `try?` for non-critical operations (scheduling retries)
- Use `do/catch` for user-facing errors (with alerts)
- Log errors with emoji prefixes for visibility (📅 ✅ ❌ ⚠️)

---

## Debugging Tips

### Enable Console Logging
AlarmService prints detailed logs:
```
📅 Scheduling alarm: 08:00 (Morning)
✅ Alarm scheduled successfully
   - Time: 8:00
   - Repeat: Weekdays
   - Captcha: Math Problem
   - Will fire in: ~120 minutes
```

### Check AlarmKit Status
```swift
let count = await AlarmService.shared.listScheduledAlarms()
print("AlarmKit has \(count) scheduled alarms")
```

### Manual Captcha Trigger
Triple-tap app → Debug Menu → "Simulate Alarm Dismiss"

### Force Snooze Limit
Set `maxSnoozes = 1` and `snoozeDuration = 1` for quick testing

### Reset All Alarms
```swift
// In DEBUG, delete all
for alarm in alarms {
    try? AlarmService.shared.cancelAlarm(id: alarm.id)
    modelContext.delete(alarm)
}
```

---

## Future Work (Phase 4)

### Shortcuts Integration
- Add Shortcut picker to AlarmEditView
- Wire up `onFireShortcutName` trigger (when alarm fires)
- Wire up `onDismissShortcutName` trigger (after captcha success)
- Use URL scheme: `shortcuts://run-shortcut?name=<encoded>`

### Other Ideas
- Gradually increasing snooze intervals
- Snooze statistics and history
- Sleep pattern analysis
- Multiple captcha types per alarm
- Photo captchas
- Barcode scanning captchas
- Custom alarm sounds

---

## Contact & Resources

- **Project Repo:** Local only (no remote configured)
- **AlarmKit Docs:** Apple Developer Documentation (iOS 26+)
- **Issue Tracking:** GitHub issues (when repo is pushed)
- **Testing:** Requires physical iOS 26+ device for full flow

---

## Quick Reference

### Most Important Files
1. `AlarmService.swift` - AlarmKit integration
2. `AlarmModel.swift` - Data model
3. `DismissAlarmIntent.swift` - Live Activity intents
4. `ContentView.swift` - Snooze limit enforcement
5. `iOzZZApp.swift` - App entry and notification routing

### Most Common Bugs
1. Forgetting to cancel alarm before deleting model
2. Not restoring original time after snooze re-schedule
3. Mixing up Calendar weekday (1-7) vs Locale.Weekday enum
4. Using `try?` where error should be shown to user
5. Testing Live Activity buttons in simulator (they don't work!)

### Testing Checklist
- [ ] Alarm schedules successfully
- [ ] Alarm fires at correct time
- [ ] Snooze increments count
- [ ] Max snooze forces captcha
- [ ] Math captcha validates correctly
- [ ] Wrong answer generates new problem
- [ ] Captcha success stops alarm
- [ ] Captcha success resets snooze count
- [ ] Delete removes from AlarmKit
- [ ] NFC tag scanning works (device only)

---

**Remember:** AlarmKit Live Activity buttons only work on physical devices. Use the Debug Menu (triple-tap) for simulator testing!
