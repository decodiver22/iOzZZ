import XCTest

final class iOzZZUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Alarm Creation Tests

    func testCreateAlarmFlow() throws {
        // Verify empty state
        XCTAssertTrue(app.staticTexts["No Alarms"].exists)

        // Tap add button
        app.buttons.matching(identifier: "plus.circle.fill").element.tap()

        // Verify alarm edit screen appears
        XCTAssertTrue(app.navigationBars["New Alarm"].exists)

        // Set time using picker (select hour and minute)
        let datePickers = app.datePickers
        XCTAssertTrue(datePickers.count > 0)

        // Select math captcha type
        let mathButton = app.buttons["Math Problem"]
        if mathButton.exists {
            mathButton.tap()
        }

        // Save alarm
        app.navigationBars.buttons["Save"].tap()

        // Verify alarm appears in list
        XCTAssertFalse(app.staticTexts["No Alarms"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS ':'")).count > 0)
    }

    func testAlarmRepeatDaysSelection() throws {
        // Create alarm
        app.buttons.matching(identifier: "plus.circle.fill").element.tap()

        // Select weekdays
        let weekdayButtons = ["Mon", "Tue", "Wed", "Thu", "Fri"]
        for day in weekdayButtons {
            if let button = app.buttons[day].firstMatch, button.exists {
                button.tap()
            }
        }

        // Verify selection (buttons should be highlighted)
        // Save and verify "Weekdays" appears
        app.navigationBars.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Weekdays"].exists)
    }

    func testAlarmCaptchaTypeSelection() throws {
        app.buttons.matching(identifier: "plus.circle.fill").element.tap()

        // Test Math captcha selection
        let mathButton = app.buttons["Math Problem"]
        if mathButton.exists {
            mathButton.tap()

            // Verify difficulty picker appears
            XCTAssertTrue(app.buttons["Easy"].exists || app.staticTexts["Easy"].exists)
            XCTAssertTrue(app.buttons["Medium"].exists || app.staticTexts["Medium"].exists)
            XCTAssertTrue(app.buttons["Hard"].exists || app.staticTexts["Hard"].exists)
        }

        // Test NFC captcha selection
        let nfcButton = app.buttons["NFC Tag"]
        if nfcButton.exists {
            nfcButton.tap()

            // Should show register NFC tag option
            XCTAssertTrue(app.buttons["Register NFC Tag"].exists || app.staticTexts["Register NFC Tag"].exists)
        }
    }

    // MARK: - Alarm List Tests

    func testAlarmToggleEnableDisable() throws {
        // Create an alarm first
        createTestAlarm()

        // Find the toggle switch
        let toggles = app.switches
        XCTAssertTrue(toggles.count > 0)

        let firstToggle = toggles.firstMatch
        let initialState = firstToggle.value as? String

        // Toggle it
        firstToggle.tap()

        // Wait a moment for state change
        sleep(1)

        let newState = firstToggle.value as? String
        XCTAssertNotEqual(initialState, newState)
    }

    func testAlarmEdit() throws {
        createTestAlarm()

        // Tap on alarm to edit
        let alarmCells = app.buttons.matching(NSPredicate(format: "label CONTAINS ':'"))
        XCTAssertTrue(alarmCells.count > 0)

        alarmCells.firstMatch.tap()

        // Verify edit screen appears
        XCTAssertTrue(app.navigationBars["Edit Alarm"].exists)

        // Change label
        let labelField = app.textFields["Alarm name"]
        if labelField.exists {
            labelField.tap()
            labelField.typeText("Morning Alarm")
        }

        // Save
        app.navigationBars.buttons["Save"].tap()

        // Verify change persisted
        XCTAssertTrue(app.staticTexts["Morning Alarm"].exists)
    }

    // MARK: - Math Captcha Tests

    func testMathCaptchaEasyGeneration() throws {
        // This tests the captcha view in isolation
        // In real usage, this would be triggered by alarm dismissal

        // For now, we can verify the CaptchaService works via unit tests
        // Full integration test would require waiting for actual alarm or mocking
    }

    func testMathCaptchaInputValidation() throws {
        // Would need to trigger captcha overlay
        // This is tested in unit tests for CaptchaService
    }

    // MARK: - Helper Methods

    private func createTestAlarm(label: String = "Test Alarm") {
        app.buttons.matching(identifier: "plus.circle.fill").element.tap()

        // Set label
        let labelField = app.textFields["Alarm name"]
        if labelField.exists {
            labelField.tap()
            labelField.clearText()
            labelField.typeText(label)
        }

        // Save
        app.navigationBars.buttons["Save"].tap()

        // Wait for alarm to appear
        sleep(1)
    }

    // MARK: - Performance Tests

    func testAlarmListPerformance() throws {
        measure {
            app.launch()
        }
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}
