import XCTest

final class FIELDMobileUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPrimaryTabsNavigate() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Recopilar"].waitForExistence(timeout: 10))
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.buttons["Laboratorio"].exists)
        XCTAssertTrue(tabs.buttons["Aprender"].exists)

        tabs.buttons["Laboratorio"].tap()
        XCTAssertTrue(app.navigationBars["Laboratorio"].waitForExistence(timeout: 5))

        tabs.buttons["Aprender"].tap()
        XCTAssertTrue(app.navigationBars["Aprender"].waitForExistence(timeout: 5))
    }

    func testCreateReferenceFromCollect() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Crear en FIELD"].tap()
        app.buttons["Referencia"].tap()

        let titleField = app.textFields["¿Qué quieres recordar?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("iPhone UI smoke reference")

        let urlField = app.textFields["Pega un enlace"]
        urlField.tap()
        urlField.typeText("https://example.com/iphone-smoke")

        app.buttons["Guardar"].tap()

        XCTAssertTrue(app.staticTexts["iPhone UI smoke reference"].waitForExistence(timeout: 8))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["iPhone UI smoke reference"].waitForExistence(timeout: 8))
    }

    func testCaptureDeepLinkPrefillsReference() {
        let app = XCUIApplication()
        app.launch()

        let destination = "https://example.com/iphone-deep-link"
        let deepLink = URL(string: "fieldlab://capture?url=https%3A%2F%2Fexample.com%2Fiphone-deep-link")!
        app.open(deepLink)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let confirmation = springboard.alerts.firstMatch
        if confirmation.waitForExistence(timeout: 3) {
            confirmation.buttons["Abrir"].tap()
        }

        XCTAssertTrue(app.navigationBars["Nueva referencia"].waitForExistence(timeout: 8))
        let urlField = app.textFields["Pega un enlace"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5))
        XCTAssertEqual(urlField.value as? String, destination)
    }
}
