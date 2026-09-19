import XCTest

/// Walks the signed-out screens and attaches a screenshot of each, in
/// portrait and landscape. Exists so an Xcode Cloud test action on the
/// iPhone Duo simulator produces something a person can look at — the
/// attachments in the test results are the only way to see a Duo layout
/// without installing a beta Xcode locally.
///
/// It stops at the sign-in code screen on purpose. The two demo numbers
/// are App Review's while 1.0 is under review, and signing in as either
/// from a test would disturb what a reviewer sees. Extend past sign-in
/// once review is done.
final class ScreenshotWalk: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    func testSignedOutScreens() {
        // The loading screen resolves to the birthdate step for a fresh
        // simulator; give the auth client a moment to report no session.
        XCTAssertTrue(app.staticTexts["What's your birthdate?"].waitForExistence(timeout: 15))
        snap("01-birthdate")

        app.buttons["Continue"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No photos. No swiping."].waitForExistence(timeout: 5))
        snap("02-intro-1")

        app.buttons["Go on"].firstMatch.tap()
        snap("03-intro-2")
        app.buttons["Go on"].firstMatch.tap()
        snap("04-intro-3")
        app.buttons["Go on"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["It's slow on purpose."].waitForExistence(timeout: 5))
        snap("05-intro-4")

        app.buttons["Create an account"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["What's your number?"].waitForExistence(timeout: 5))
        snap("06-phone")

        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("5555550199")   // reserved fictional number; never sent
        snap("07-phone-filled")

        element(labelled: "Lost your number? Sign in with email").tap()
        XCTAssertTrue(app.staticTexts["Sign in with email"].waitForExistence(timeout: 5)
                      || app.textFields.firstMatch.waitForExistence(timeout: 5))
        snap("08-email-sign-in")
    }

    /// SwiftUI reports a SecondaryLink as a button on one OS and static
    /// text on another; match on the label, whatever the element type.
    private func element(labelled label: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }

    /// One attachment per orientation, kept regardless of pass/fail.
    private func snap(_ name: String) {
        for (orientation, suffix) in [(UIDeviceOrientation.portrait, "portrait"), (.landscapeLeft, "landscape")] {
            XCUIDevice.shared.orientation = orientation
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.5))
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(name)-\(suffix)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
