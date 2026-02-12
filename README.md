# iOzZZ 🚨

A smart iOS alarm app that makes sure you actually wake up by requiring a captcha to dismiss.

## Features

### 🧮 Math Captcha
Solve a math problem to prove you're awake before dismissing the alarm.
- **Easy:** Addition and subtraction (10-99)
- **Medium:** Multiplication (6-15)
- **Hard:** Multi-step equations

### 📱 NFC Tag Captcha
Register NFC tags and require scanning them to dismiss alarms. Perfect for placing tags in another room!

### 😴 Smart Snooze Limits
Configure maximum snooze attempts (1-10 or unlimited). After reaching the limit, you're forced to solve the captcha - no more infinite snoozing!

### 🎨 Beautiful Design
- Immersive full-screen captcha experience
- Liquid glass card effects
- Large, easy-to-read typography
- Dark gradient backgrounds

### 🔁 Flexible Scheduling
- One-time or recurring alarms
- Weekly repeat patterns
- Quick presets: Weekdays, Weekends, Every day

## Requirements

- iOS 26.0 or later (AlarmKit requirement)
- Xcode 16 beta or later
- NFC-capable iPhone (for NFC captcha feature)

## How It Works

### The Alarm Flow

1. **Alarm Fires** → System notification appears with two buttons:
   - **Snooze (❌):** Stops alarm and re-schedules it for later
   - **Dismiss (✓):** Opens app and shows captcha

2. **Snooze Behavior:**
   - Increments snooze counter
   - Checks if max snoozes reached
   - If under limit: Re-schedules alarm for X minutes later
   - If limit reached: Forces captcha instead

3. **Dismiss Behavior:**
   - Opens app to full-screen captcha
   - Math: Solve the problem correctly
   - NFC: Scan the registered tag
   - Wrong answer generates new problem
   - Correct answer stops alarm and resets snooze count

### Why It Works

Unlike regular alarms where you can keep hitting snooze forever, iOzZZ forces you to:
1. **Wake up enough** to solve a math problem or get out of bed to scan an NFC tag
2. **Actually engage your brain** which naturally wakes you up
3. **Face consequences** for excessive snoozing (forced captcha after limit)

## Installation

### Clone and Build

```bash
git clone <your-repo-url>
cd iOzZZ
open iOzZZ.xcodeproj
```

### Build in Xcode
1. Select your target device or simulator
2. Press `⌘R` to build and run

### Device Testing

**Note:** AlarmKit's Live Activity buttons (Snooze/Dismiss) only work on physical devices running iOS 26+. The simulator will show basic notifications without interactive buttons.

For full testing:
1. Connect iPhone running iOS 26 beta
2. Select device in Xcode
3. Build and run
4. Create test alarm
5. Lock device and wait for alarm to fire

## Project Structure

```
iOzZZ/
├── iOzZZ/
│   ├── Services/
│   │   ├── AlarmService.swift      # AlarmKit integration
│   │   ├── CaptchaService.swift    # Math problem generator
│   │   └── NFCService.swift        # NFC tag scanning
│   ├── Models/
│   │   ├── AlarmModel.swift        # Alarm configuration
│   │   └── NFCTagModel.swift       # Registered NFC tags
│   ├── Views/
│   │   ├── AlarmListView.swift     # Main screen
│   │   ├── AlarmEditView.swift     # Create/edit alarms
│   │   ├── MathCaptchaView.swift   # Math problem UI
│   │   └── NFCCaptchaView.swift    # NFC scan UI
│   └── Intents/
│       └── DismissAlarmIntent.swift # Live Activity buttons
└── iOzZZTests/                      # Unit tests
```

## Usage

### Creating an Alarm

1. Tap **+** in the top right
2. Set your desired time
3. Choose alarm label
4. Select repeat days (or leave empty for one-time)
5. Pick captcha type (Math or NFC)
6. Configure snooze duration (1-15 minutes)
7. Set max snoozes (1-10 or unlimited)
8. Tap **Save**

### Registering an NFC Tag

1. Create or edit an alarm
2. Set Captcha Type to "NFC Tag"
3. Tap **Register NFC Tag**
4. Hold your iPhone near the NFC tag
5. Give it a name (e.g., "Kitchen Tag")
6. Select the tag for your alarm

**Tip:** Place NFC tags somewhere that forces you to get out of bed (bathroom mirror, kitchen counter, etc.)

### Editing an Alarm

1. Tap any alarm card
2. Modify settings
3. Tap **Save**

### Deleting an Alarm

**Option 1:** Swipe left on alarm card → Tap **Delete**

**Option 2:** Tap alarm → Scroll to bottom → Tap **Delete Alarm**

## Configuration Examples

### Wake Up Enforcer
Perfect for heavy sleepers who need strict limits:
```
Snooze Duration: 3 minutes
Max Snoozes: 1
Captcha: Math (Hard)
```
Result: Only one 3-minute snooze, then forced to solve difficult math

### Balanced Approach
Good default for most users:
```
Snooze Duration: 5 minutes
Max Snoozes: 3
Captcha: Math (Medium)
```
Result: 15 minutes total snooze time, then moderate difficulty

### Gentle Mode
For those who want flexibility:
```
Snooze Duration: 10 minutes
Max Snoozes: Unlimited
Captcha: Math (Easy)
```
Result: Can snooze as much as needed, easy captcha when dismissing

## Testing

### Unit Tests
```bash
⌘U in Xcode
```

Tests cover:
- Math problem generation (all difficulty levels)
- Answer validation (correct, wrong, edge cases)
- Alarm model helpers

### Debug Menu

For simulator testing (since Live Activity buttons don't work):

1. **Triple-tap** anywhere in the app to open Debug Menu
2. Available actions:
   - **Create Test Alarm:** Makes alarm 90s in future
   - **Simulate Alarm Dismiss:** Manually trigger captcha
   - **Test Captcha:** Try captcha for any alarm
   - **Check AlarmKit Status:** See scheduled alarms

## Known Issues

### iOS 26 Beta
- AppIntentsSSUTraining error on device builds (beta framework issue)
- Some device builds may fail - use simulator for development

### Simulator Limitations
- AlarmKit Live Activity buttons don't render
- NFC scanning uses mock implementation
- Can't test full alarm flow end-to-end

**Workaround:** Use Debug Menu (triple-tap) for simulator testing

## Architecture

### Core Technologies
- **SwiftUI** - Modern declarative UI
- **SwiftData** - Persistence layer
- **AlarmKit** - System alarm scheduling (iOS 26+)
- **Core NFC** - NFC tag reading
- **App Intents** - Live Activity custom buttons

### Key Patterns
- `@Observable` for services
- `@MainActor` for UI-bound operations
- Notification-based communication between intents and app
- Manual snooze re-scheduling (more reliable than AlarmKit's postAlert)

### Why Manual Snooze Re-scheduling?

AlarmKit's `postAlert` duration proved unreliable. Instead, we:
1. Cancel the current alarm
2. Calculate snooze time (now + duration)
3. Schedule new alarm for that time
4. Restore original display time

This gives us full control and integrates perfectly with max snooze limits.

## Contributing

### Code Style
- Follow Swift API Design Guidelines
- Add file headers to new files
- Document complex logic with inline comments
- Use meaningful variable names
- Keep functions focused and small

### Testing Requirements
- Add unit tests for new business logic
- Test on physical device for AlarmKit features
- Verify NFC on NFC-capable device

### Pull Request Process
1. Create feature branch
2. Write tests for new features
3. Update documentation
4. Test on device if changing AlarmKit/NFC code
5. Submit PR with clear description

## Future Plans

### Phase 4: Shortcuts Integration
- Trigger Apple Shortcuts when alarm fires
- Trigger Shortcuts when alarm is dismissed
- Example use cases:
  - Turn on lights when alarm fires
  - Start coffee machine
  - Log wake-up time to Health app

### Other Ideas
- Photo captchas (match the photo)
- Barcode scanning captchas
- Gradually increasing snooze intervals
- Sleep statistics and patterns
- Multiple captcha types per alarm
- Custom alarm sounds
- Wake-up challenges (squats, steps, etc.)

## License

[Add your license here]

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check existing documentation in `CLAUDE.md`
- Review implementation notes in `IMPLEMENTATION_COMPLETE.md`

## Acknowledgments

Built with:
- Apple's AlarmKit framework (iOS 26+)
- SwiftUI and SwiftData
- Core NFC
- Lots of ☕ and late-night coding

---

**Made with 💙 to help you actually wake up on time**
