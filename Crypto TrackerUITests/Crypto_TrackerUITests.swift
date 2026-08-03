import XCTest

@MainActor
final class CryptoTrackerUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-AppleLanguages")
        app.launchArguments.append("(en)")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppLaunches() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testSidebarNavigationExists() throws {
        app.launch()

        let sidebar = app.outlines["main-sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        XCTAssertTrue(sidebar.buttons["main-menu-portfolio"].exists)
        XCTAssertTrue(sidebar.buttons["main-menu-portfolio-by-cryptos"].exists)
        XCTAssertTrue(sidebar.buttons["main-menu-portfolio-by-wallets"].exists)
    }

    func testMainMenuGroupsExist() throws {
        app.launch()

        let sidebar = app.outlines["main-sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        XCTAssertTrue(sidebar.buttons["main-menu-movements"].exists)
        XCTAssertTrue(sidebar.buttons["main-menu-admin"].exists)
    }

    func testNavigationToPortfolioByCryptos() throws {
        app.launch()

        let sidebar = app.outlines["main-sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        sidebar.buttons["main-menu-portfolio-by-cryptos"].tap()
        XCTAssertTrue(app.scrollViews["portfolio-cryptos-view"].waitForExistence(timeout: 5))
    }

    func testNavigationToWalletBreakdown() throws {
        app.launch()

        let sidebar = app.outlines["main-sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        sidebar.buttons["main-menu-portfolio-by-wallets"].tap()
        XCTAssertTrue(app.scrollViews["portfolio-detail-view"].waitForExistence(timeout: 5))
    }
}

final class CryptoTrackerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
