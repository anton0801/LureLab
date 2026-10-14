import XCTest

/// End-to-end flows on an empty in-memory journal (DEBUG scenario "e2e"; never touches the real store).
final class LureLabFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["LURELAB_SCENARIO"] = "e2e"
        app.launch()
    }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    private func tapHittable(_ query: XCUIElementQuery, _ label: String, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let matches = query.matching(identifier: label).allElementsBoundByIndex
            if let target = matches.first(where: { $0.exists && $0.isHittable }) {
                target.tap()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        print("HIERARCHY-BEGIN\n\(app.debugDescription)\nHIERARCHY-END")
        XCTFail("No hittable element labelled \(label)")
    }

    private func type(into label: String, _ text: String) {
        let field = app.textFields[label]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "missing field \(label)")
        field.tap()
        field.typeText(text)
    }

    func testFirstLaunchToCraftingFlow() throws {
        // 01–03 onboarding.
        tapHittable(app.buttons, "Next")
        tapHittable(app.buttons, "Next")
        tapHittable(app.buttons, "Get Started")

        // 05 empty workbench → 11 Add Lure.
        XCTAssertTrue(app.staticTexts["Your workbench is ready"].waitForExistence(timeout: 5))
        tapHittable(app.buttons, "+ Add Your First Lure")
        type(into: "Name *", "Test Minnow\n")
        tapHittable(app.buttons, "Type, not chosen")
        tapHittable(app.buttons, "Minnow")
        tapHittable(app.buttons, "Save Lure")

        // 10 Lure Detail → 13 Log a Test.
        XCTAssertTrue(app.staticTexts["Test Minnow"].waitForExistence(timeout: 5))
        tapHittable(app.buttons, "Log a Test")
        type(into: "Duration · Minutes *", "45")
        app.toolbars.buttons["Done"].tap()
        type(into: "Place *", "North Pier\n")
        tapHittable(app.buttons, "Increase bites")
        tapHittable(app.buttons, "Increase bites")
        tapHittable(app.buttons, "Increase catches")
        tapHittable(app.buttons, "Save Test")

        // 16 Test Saved: capsule only after the commit.
        XCTAssertTrue(app.staticTexts["Test Saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "1 capsule earned").exists)
        tapHittable(app.buttons, "Open Workshop")

        // 19 → 20 Lucky Cast → 22 result.
        XCTAssertTrue(element(containing: "1 capsule").waitForExistence(timeout: 5))
        tapHittable(app.buttons, "Lucky Cast")
        tapHittable(app.buttons, "CAST")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Result saved"].exists)
        XCTAssertTrue(element(containing: "Added to your workshop").exists)
        tapHittable(app.buttons, "Done")
        XCTAssertTrue(element(containing: "0 capsules").waitForExistence(timeout: 5))

        // 24 Showcase → 27 locked (1–3 Parts after one cast).
        tapHittable(app.buttons, "My Showcase")
        XCTAssertTrue(app.staticTexts["Your collection"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "0 of 4 crafted").exists)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        tapHittable(app.buttons, "Coral Comet, costs 3 Parts")
        if !app.staticTexts["WORKSHOP COLLECTION"].waitForExistence(timeout: 5) {
            print("HIERARCHY-BEGIN\n\(app.debugDescription)\nHIERARCHY-END")
            XCTFail("collectible detail did not open")
        }
        let canCraft = app.buttons["Craft for 3 Parts"].exists
        if canCraft {
            tapHittable(app.buttons, "Craft for 3 Parts")
            XCTAssertTrue(app.staticTexts["Made it yours!"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(element(containing: "More Part").exists)
        }
    }

    func testValidationDraftAndJournal() throws {
        tapHittable(app.buttons, "Skip")
        tapHittable(app.buttons, "+ Add Your First Lure")
        type(into: "Name *", "Copper Spinner\n")
        tapHittable(app.buttons, "Type, not chosen")
        tapHittable(app.buttons, "Spinner")
        tapHittable(app.buttons, "Save Lure")
        tapHittable(app.buttons, "Log a Test")

        // 40: Save with missing duration shows inline errors and saves nothing.
        type(into: "Place *", "Willow Lake\n")
        tapHittable(app.buttons, "Decrease bites")   // − from unknown records 0
        tapHittable(app.buttons, "Increase catches")
        tapHittable(app.buttons, "Save Test")
        XCTAssertTrue(element(containing: "Enter a duration from 1 to 1440 min.").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Catches cannot exceed recorded bites.").exists)

        // 38: leaving with changes asks to keep the draft (the form scrolled to the first error).
        app.scrollViews.firstMatch.swipeDown()
        app.scrollViews.firstMatch.swipeDown()
        tapHittable(app.buttons, "Back")
        XCTAssertTrue(app.staticTexts["Keep This Draft?"].waitForExistence(timeout: 5))
        tapHittable(app.buttons, "Save Draft and Leave")

        // The draft is restored on the next Log a Test.
        tapHittable(app.buttons, "Log a Test")
        XCTAssertEqual(app.textFields["Place *"].value as? String, "Willow Lake")
        type(into: "Duration · Minutes *", "30")
        app.toolbars.buttons["Done"].tap()
        tapHittable(app.buttons, "Increase bites")
        tapHittable(app.buttons, "Increase bites")
        tapHittable(app.buttons, "Save Test")
        XCTAssertTrue(app.staticTexts["Test Saved"].waitForExistence(timeout: 5))
        tapHittable(app.buttons, "Back to Journal")

        // 04 → 06 journal list shows the saved test.
        XCTAssertTrue(app.staticTexts["Latest test"].waitForExistence(timeout: 5))
        tapHittable(app.buttons, "View all tests")
        XCTAssertTrue(element(containing: "Willow Lake").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "30 min · 2 bites · 1 catch").exists, "0 → +2 bites, 1 catch")
    }

    func testUnitsSwitchToImperial() throws {
        tapHittable(app.buttons, "Skip")
        tapHittable(app.buttons, "+ Add Your First Lure")
        type(into: "Name *", "Reed Tail\n")
        tapHittable(app.buttons, "Type, not chosen")
        tapHittable(app.buttons, "Soft bait")
        type(into: "Length · Cm", "10.16")
        tapHittable(app.buttons, "Save Lure")
        XCTAssertTrue(element(containing: "10.2 cm").waitForExistence(timeout: 5))
        tapHittable(app.buttons, "Back")
        tapHittable(app.buttons, "Settings")
        tapHittable(app.buttons, "Units, Metric")
        tapHittable(app.buttons, "Imperial")
        tapHittable(app.buttons, "Done")
        tapHittable(app.buttons, "Back")
        tapHittable(app.buttons, "Lures")
        XCTAssertTrue(element(containing: "4 in").waitForExistence(timeout: 5))
    }

    func testComparePickerAndInterruptedCast() throws {
        tapHittable(app.buttons, "Skip")
        for (name, minutes) in [("Alpha Minnow", "40"), ("Beta Spinner", "50")] {
            tapHittable(app.buttons, "Lures")
            // Empty catalogue shows the "+ Add Lure" CTA; afterwards the header plus button.
            tapHittable(app.buttons, app.buttons["+ Add Lure"].waitForExistence(timeout: 2) ? "+ Add Lure" : "Add Lure")
            type(into: "Name *", "\(name)\n")
            tapHittable(app.buttons, "Type, not chosen")
            tapHittable(app.buttons, "Minnow")
            tapHittable(app.buttons, "Save Lure")
            tapHittable(app.buttons, "Log a Test")
            type(into: "Duration · Minutes *", minutes)
            app.toolbars.buttons["Done"].tap()
            type(into: "Place *", "Bay\n")
            tapHittable(app.buttons, "Increase catches")
            tapHittable(app.buttons, "Save Test")
            XCTAssertTrue(app.staticTexts["Test Saved"].waitForExistence(timeout: 5))
            tapHittable(app.buttons, "Back to Journal")
        }

        // Compare → Choose Lure: the tab bar must not cover the picker's Done button.
        tapHittable(app.buttons, "Compare")
        tapHittable(app.buttons, "Comparing Beta Spinner and Alpha Minnow")
        XCTAssertTrue(app.staticTexts["Choose Lure"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Journal"].isHittable, "tab bar is hidden while the picker is open")
        tapHittable(app.buttons, "Done")
        XCTAssertTrue(app.staticTexts["Catches per hour"].waitForExistence(timeout: 5))

        // Lucky Cast: leaving during the reels keeps the committed result pending; it is shown on return.
        tapHittable(app.buttons, "Workshop")
        tapHittable(app.buttons, "Lucky Cast")
        tapHittable(app.buttons, "CAST")
        tapHittable(app.buttons, "Back")
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        tapHittable(app.buttons, "Lucky Cast")
        XCTAssertTrue(app.staticTexts["Result saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Added to your workshop").exists)
    }
}
