# iOzZZ Alarm Testing Guide

**Created:** 2026-02-12 00:00
**Purpose:** Test alarm firing and captcha functionality
**Platform:** iOS 26.2 Simulator (or Device when build fixed)

---

## 🐛 Debug Menu Access

### Visual Location
Look for the **ant icon (🐛)** in the **top-left** corner of the app

### What It Provides
1. **Create Test Alarm** - Fires in 90 seconds
2. **Check AlarmKit Status** - See how many alarms are actually scheduled
3. **Test Captcha** - Manually trigger captcha for any alarm

---

## 🧪 Quick Test Flow (90 Second Test)

### Step 1: Open Debug Menu
- Tap the ant icon (🐛) in top-left corner

### Step 2: Create Test Alarm
- Tap "Create Test Alarm" button
- A new alarm will be created for **90 seconds from now**
- You'll see: "✅ Test alarm created! Wait 90 seconds..."

### Step 3: Wait for Alarm
- **Keep the app open** OR lock the simulator (Cmd+L)
- Wait 90 seconds
- **Expected:** Alarm notification appears

### Step 4: Dismiss with Captcha
- When alarm fires, tap **"Dismiss"** button
- **Expected:** App opens and captcha overlay appears
- Solve the math problem
- **Expected:** Alarm stops

---

## 🔍 Check AlarmKit Status

### Purpose
Verify that alarms are actually scheduled in AlarmKit (not just SwiftData)

### Steps
1. Open debug menu (tap ant icon)
2. Tap "Check AlarmKit Status"
3. Look at the output: "X alarm(s) in AlarmKit"
4. Check console logs for details

### Console Output
```
📋 AlarmKit has X scheduled alarm(s)
   - Alarm ID: [UUID]
   - Alarm ID: [UUID]
```

### What to Look For
- **0 alarms** = Alarms aren't being scheduled (bug!)
- **1+ alarms** = Scheduling works, alarm should fire

---

## 🎯 Manual Captcha Test (Instant)

### Purpose
Test captcha UI without waiting for alarm to fire

### Steps
1. Open debug menu (tap ant icon)
2. Under "Test Captcha for:", tap any alarm
3. Captcha overlay appears immediately
4. Test solving math problems:
   - Enter **wrong answer** → See error message + new problem
   - Enter **correct answer** → Captcha dismisses

### What to Test
- ✅ Math problem displays correctly
- ✅ Number input works
- ✅ Wrong answer shows red border + error
- ✅ New problem generated after wrong answer
- ✅ Correct answer dismisses captcha
- ✅ Liquid glass effects look good

---

## 📊 Understanding Alarm Scheduling

### How Relative Time Works
When you create an alarm for a specific time (e.g., 23:35):
- If **current time is before 23:35**: Alarm fires **today** at 23:35
- If **current time is after 23:35**: Alarm fires **tomorrow** at 23:35

### Example
```
Current time: 23:59
Create alarm for: 23:35
Will fire at: Tomorrow at 23:35 (in ~23 hours)
```

### Solution for Testing
Use the **"Create Test Alarm"** button which always fires 90 seconds from now

---

## 📋 Complete Test Checklist

### Alarm Creation
- [ ] Open app, tap + button
- [ ] Set time, label, captcha type
- [ ] Tap Save
- [ ] Alarm appears in list with toggle ON

### Debug Menu
- [ ] Tap ant icon (🐛) - debug menu appears
- [ ] Create test alarm - shows success message
- [ ] Check AlarmKit status - shows count
- [ ] Test captcha for existing alarm - captcha appears

### Alarm Firing (90 Second Test)
- [ ] Create test alarm (90 seconds)
- [ ] Wait for notification to appear
- [ ] Notification shows "Snooze" and "Dismiss" buttons
- [ ] Tap "Snooze" - alarm stops, re-fires after snooze duration
- [ ] Tap "Dismiss" - app opens

### Captcha Flow
- [ ] Captcha overlay appears over app
- [ ] Math problem displays clearly
- [ ] Enter wrong answer - see red border + error
- [ ] New problem generated automatically
- [ ] Enter correct answer - captcha dismisses
- [ ] Alarm stops (no longer firing)

### Visual Quality
- [ ] Liquid glass alarm cards look premium
- [ ] Captcha view has dark gradient background
- [ ] Math problem card has multi-layer glass effect
- [ ] Answer input has dynamic styling
- [ ] Submit button has gradient + glow

---

## 🔧 Troubleshooting

### Alarm Doesn't Fire
**Possible causes:**
1. **Simulator limitations** - AlarmKit may not work reliably in simulator
2. **Notifications disabled** - Check simulator notification settings
3. **Time already passed** - Alarm scheduled for tomorrow (use test alarm instead)
4. **Not scheduled** - Check AlarmKit status (should show 1+ alarms)

**Solutions:**
- ✅ Use "Create Test Alarm" (fires in 90 seconds)
- ✅ Test on physical device (when build fixed)
- ✅ Check console logs for scheduling confirmation

### Captcha Doesn't Appear
**Possible causes:**
1. **Intents disabled** - DismissAlarmIntent not registered (device build issue)
2. **App not opening** - `openAppWhenRun = false` bug
3. **Notification listener issue** - NotificationCenter not receiving event

**Solutions:**
- ✅ Use debug menu "Test Captcha" to verify UI works
- ✅ Check console for "📬 Received dismissAlarmRequested notification"
- ✅ On device, rebuild with intents enabled (fix AppIntentsSSUTraining first)

### Debug Menu Won't Open
**Solutions:**
- ✅ Look for ant icon (🐛) in top-left corner
- ✅ Make sure you're in Debug build (not Release)
- ✅ Rebuild app if icon not visible

---

## 📱 Console Logs to Watch

### Successful Alarm Scheduling
```
📅 Scheduling alarm: 23:45 (Test Alarm)
✅ Authorized, scheduling alarm with ID: [UUID]
✅ Alarm scheduled successfully
   - Time: 23:45
   - Repeat: One-time
   - Captcha: Math Problem
   - Snooze: 1 min
   - Will fire in: ~1 minutes (11:45 PM)
   - Result: Alarm(id: [UUID])
```

### Alarm Firing
```
📬 Received dismissAlarmRequested notification
✅ Showing captcha for alarm: [UUID]
```

### AlarmKit Status
```
📋 AlarmKit has 2 scheduled alarm(s)
   - Alarm ID: [UUID-1]
   - Alarm ID: [UUID-2]
```

---

## 🎯 Success Criteria

### Must Work
- ✅ Create test alarm (90 seconds)
- ✅ Alarm appears in AlarmKit status
- ✅ Console shows scheduling confirmation
- ✅ Captcha test via debug menu works
- ✅ Math problem solving works correctly

### Should Work (Simulator Dependent)
- ⚠️ Alarm notification fires at scheduled time
- ⚠️ Tapping "Dismiss" opens app
- ⚠️ Captcha appears automatically
- ⚠️ Correct answer stops alarm

### Blocked on Device (Until Build Fixed)
- ❌ Intents work on device
- ❌ Full end-to-end flow on iPhone

---

## 🚀 Next Steps After Testing

### If Test Alarm Works
1. ✅ Verify captcha appears when dismissed
2. ✅ Test different difficulty levels
3. ✅ Test snooze functionality
4. ✅ Fix device build (AppIntentsSSUTraining error)

### If Test Alarm Doesn't Fire
1. ⚠️ Check AlarmKit status (debug menu)
2. ⚠️ Review console logs for errors
3. ⚠️ Test on physical device (if possible)
4. ⚠️ Investigate simulator limitations

---

## 📄 Related Documentation

- **UX_IMPROVEMENTS_REPORT.md** - Visual improvements details
- **SIMULATOR_TEST_RESULTS.md** - Automated test results
- **TEST_REPORT.md** - Overall test status

---

**Pro Tip:** Start with the debug menu "Test Captcha" feature to verify the UI works perfectly, then use "Create Test Alarm" to test the full alarm firing flow.
