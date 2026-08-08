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
#if os(macOS)
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
#else
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
#endif
    }

    func testPrimaryNavigationExistsOnCurrentPlatform() throws {
        app.launch()

        let sidebar = app.outlines["main-sidebar"]
        if sidebar.waitForExistence(timeout: 2) {
            XCTAssertTrue(sidebar.buttons["main-menu-portfolio"].exists)
            XCTAssertTrue(sidebar.buttons["main-menu-portfolio-by-cryptos"].exists)
            XCTAssertTrue(sidebar.buttons["main-menu-portfolio-by-wallets"].exists)
        } else {
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
            XCTAssertEqual(tabBar.buttons.count, 3)
        }
    }

    func testSectionNavigationExistsOnCurrentPlatform() throws {
        app.launch()

        let sidebar = app.outlines["main-sidebar"]
        if sidebar.waitForExistence(timeout: 2) {
            XCTAssertTrue(element("main-menu-movements").exists)
            XCTAssertTrue(element("main-menu-admin").exists)
        } else {
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
            XCTAssertTrue(tabBar.buttons.element(boundBy: 1).exists)
            XCTAssertTrue(tabBar.buttons.element(boundBy: 2).exists)
        }
    }

    func testNavigationToPortfolioByCryptos() throws {
        app.launch()

        navigate(to: Route(menu: "main-menu-portfolio-by-cryptos", destination: "portfolio-cryptos-view", section: .portfolio))
    }

    func testNavigationToWalletBreakdown() throws {
        app.launch()

        navigate(to: Route(menu: "main-menu-portfolio-by-wallets", destination: "portfolio-detail-view", section: .portfolio))
    }

    func testEveryMainRouteIsReachable() throws {
        let routes = [
            Route(menu: "main-menu-portfolio", destination: "portfolio-view", section: .portfolio),
            Route(menu: "main-menu-portfolio-by-cryptos", destination: "portfolio-cryptos-view", section: .portfolio),
            Route(menu: "main-menu-portfolio-by-wallets", destination: "portfolio-detail-view", section: .portfolio),
            Route(menu: "main-menu-movements-entry", destination: "movements-entry-view", section: .movements),
            Route(menu: "main-menu-movements-exit", destination: "movements-exit-view", section: .movements),
            Route(menu: "main-menu-movements-between-wallets", destination: "movements-transfer-view", section: .movements),
            Route(menu: "main-menu-movements-swaps", destination: "movements-swaps-view", section: .movements),
            Route(menu: "main-menu-movements-search", destination: "movements-search-view", section: .movements),
            Route(menu: "main-menu-admin-cryptos", destination: "admin-cryptos-view", section: .admin),
            Route(menu: "main-menu-admin-wallets", destination: "admin-wallets-view", section: .admin),
            Route(menu: "main-menu-admin-fiat", destination: "admin-fiat-view", section: .admin),
            Route(menu: "main-menu-admin-portfolios", destination: "admin-portfolios-view", section: .admin),
            Route(menu: "main-menu-admin-sync", destination: "admin-sync-view", section: .admin),
            Route(menu: "main-menu-admin-backup", destination: "admin-backup-view", section: .admin),
            Route(menu: "main-menu-admin-setup", destination: "admin-setup-view", section: .admin)
        ]

        for route in routes {
            app.launch()
            navigate(to: route)
        }
    }

    func testPrimaryCreateFormsOpenAndCancel() throws {
        let flows = [
            CreateFlow(route: Route(menu: "main-menu-movements-entry", destination: "movements-entry-view", section: .movements), add: "movement-entry-add", cancel: "movement-entry-cancel"),
            CreateFlow(route: Route(menu: "main-menu-movements-exit", destination: "movements-exit-view", section: .movements), add: "movement-exit-add", cancel: "movement-exit-cancel"),
            CreateFlow(route: Route(menu: "main-menu-movements-between-wallets", destination: "movements-transfer-view", section: .movements), add: "movement-transfer-add", cancel: "movement-transfer-cancel"),
            CreateFlow(route: Route(menu: "main-menu-movements-swaps", destination: "movements-swaps-view", section: .movements), add: "movement-swap-add", cancel: "movement-swap-cancel"),
            CreateFlow(route: Route(menu: "main-menu-admin-cryptos", destination: "admin-cryptos-view", section: .admin), add: "admin-cryptos-add", cancel: "admin-crypto-form-cancel"),
            CreateFlow(route: Route(menu: "main-menu-admin-wallets", destination: "admin-wallets-view", section: .admin), add: "admin-wallets-add", cancel: "admin-wallet-form-cancel"),
            CreateFlow(route: Route(menu: "main-menu-admin-fiat", destination: "admin-fiat-view", section: .admin), add: "admin-fiat-add", cancel: "admin-fiat-form-cancel"),
            CreateFlow(route: Route(menu: "main-menu-admin-portfolios", destination: "admin-portfolios-view", section: .admin), add: "admin-portfolios-add", cancel: "admin-portfolio-form-cancel")
        ]

        for flow in flows {
            app.launch()
            navigate(to: flow.route)
            let addButton = app.buttons[flow.add].firstMatch
            XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Missing add control: \(flow.add)")
            addButton.tap()

            let cancelButton = app.buttons[flow.cancel].firstMatch
            XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Missing cancel control: \(flow.cancel)")
            cancelButton.tap()
            XCTAssertFalse(cancelButton.waitForExistence(timeout: 2), "Form did not close: \(flow.cancel)")
        }
    }

    func testSetupBackupOptionOpensRealBackupScreen() throws {
        app.launch()
        navigate(to: Route(menu: "main-menu-admin-setup", destination: "admin-setup-view", section: .admin))

        let backupOption = app.buttons["setup-option-backup"].firstMatch
        for _ in 0..<3 where !backupOption.exists {
            app.swipeUp()
        }
        XCTAssertTrue(backupOption.waitForExistence(timeout: 5), "Backup option was not reachable in setup")
        backupOption.tap()

        XCTAssertTrue(element("admin-backup-view").waitForExistence(timeout: 5))
        let closeButton = app.buttons["setup-backup-close"].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
    }

    private func navigate(to route: Route) {
        let sidebar = app.outlines["main-sidebar"]
        let usesSidebar = sidebar.exists || sidebar.waitForExistence(timeout: 2)
        if usesSidebar {
            if let group = route.section.sidebarGroup,
               !sidebar.buttons[route.menu].exists {
                let disclosure = element(group)
                XCTAssertTrue(disclosure.waitForExistence(timeout: 5), "Missing sidebar group: \(group)")
                disclosure.tap()
            }
            let menu = sidebar.buttons[route.menu]
            XCTAssertTrue(menu.waitForExistence(timeout: 5), "Missing menu: \(route.menu)")
            menu.tap()
        } else {
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Missing tab bar")
            let tab = tabBar.buttons.element(boundBy: route.section.tabIndex)
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab: \(route.section.tabIdentifier)")
            tab.tap()

            let menu = element(route.menu)
            XCTAssertTrue(menu.waitForExistence(timeout: 5), "Missing menu: \(route.menu)")
            menu.tap()
        }

        XCTAssertTrue(element(route.destination).waitForExistence(timeout: 5), "Route did not open: \(route.destination)")

    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}

private struct Route {
    let menu: String
    let destination: String
    let section: AppSection
}

private struct CreateFlow {
    let route: Route
    let add: String
    let cancel: String
}

private enum AppSection {
    case portfolio
    case movements
    case admin

    var sidebarGroup: String? {
        switch self {
        case .portfolio: nil
        case .movements: "main-menu-movements"
        case .admin: "main-menu-admin"
        }
    }

    var tabIdentifier: String {
        switch self {
        case .portfolio: "tab-portfolio"
        case .movements: "tab-movements"
        case .admin: "tab-admin"
        }
    }

    var tabIndex: Int {
        switch self {
        case .portfolio: 0
        case .movements: 1
        case .admin: 2
        }
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
