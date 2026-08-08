import SwiftUI
import SwiftData

enum MainMenuOption {
    case home
    case portfolioCryptos
    case portfolioDetalle
    case administracion
    case movimientos
}

enum AdminMenuOption {
    case cryptos
    case carteras
    case fiat
    case portfolios
    case sync
    case backup
    case setup  //  caso para Setup Inicial
}

enum MovimientosMenuOption {
    case entrada
    case salida
    case entreCarteras
    case swaps
    case search
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Contenedor de dependencias
    private let dependencies: AppDependencyContainer
    
    // Inicializador que recibe el contenedor de dependencias
    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
    }
    
    @State private var selectedMainMenu: MainMenuOption? = .home
    @State private var selectedAdminMenu: AdminMenuOption?
    @State private var selectedMovimientosMenu: MovimientosMenuOption?
    @State private var movementsMenuIsExpanded = true
    @State private var adminMenuIsExpanded = true
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                iosTabView
            } else {
                macSidebar
            }
        }
    }
    
    // MARK: - macOS: NavigationSplitView con sidebar (comportamiento actual)
    private var macSidebar: some View {
        NavigationSplitView {
            // Sidebar con menú principal
            List {
                // Opción Home
                NavigationLink(
                    destination: dependencies.makePortfolioView()
                        .accessibilityIdentifier("portfolio-view"),
                    tag: MainMenuOption.home,
                    selection: $selectedMainMenu
                ) {
                    Label(String(localized: "menu_portfolio"), systemImage: "chart.pie.fill")
                }
                .accessibilityIdentifier("main-menu-portfolio")
                
                NavigationLink(
                    destination: dependencies.makePortfolioPorCryptosView()
                        .accessibilityIdentifier("portfolio-cryptos-view"),
                    tag: MainMenuOption.portfolioCryptos,
                    selection: $selectedMainMenu
                ) {
                    Label(String(localized: "menu_portfolio_by_cryptos"), systemImage: "bitcoinsign.square.fill")
                }
                .accessibilityIdentifier("main-menu-portfolio-by-cryptos")
                
                NavigationLink(
                    destination: dependencies.makePortfolioDetalleView()
                        .accessibilityIdentifier("portfolio-detail-view"),
                    tag: MainMenuOption.portfolioDetalle,
                    selection: $selectedMainMenu
                ) {
                    Label(String(localized: "menu_portfolio_by_wallets"), systemImage: "list.bullet.rectangle.portrait")
                }
                .accessibilityIdentifier("main-menu-portfolio-by-wallets")
                
                // Menú Movimientos
                DisclosureGroup(
                    isExpanded: $movementsMenuIsExpanded,
                    content: {
                        NavigationLink(
                            destination: dependencies.makeMovimientosEntradaView(),
                            tag: .entrada,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label(String(localized: "menu_movements_entry"), systemImage: "arrow.down.circle")
                        }
                        .accessibilityIdentifier("main-menu-movements-entry")
                        
                        NavigationLink(
                            destination: dependencies.makeMovimientosSalidaView(),
                            tag: .salida,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label(String(localized: "menu_movements_exit"), systemImage: "arrow.up.circle")
                        }
                        .accessibilityIdentifier("main-menu-movements-exit")
                        
                        NavigationLink(
                            destination: dependencies.makeMovimientosEntreCarterasView(),
                            tag: .entreCarteras,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label(String(localized: "menu_movements_between_wallets"), systemImage: "arrow.left.arrow.right")
                        }
                        .accessibilityIdentifier("main-menu-movements-between-wallets")
                        
                        NavigationLink(
                            destination: dependencies.makeMovimientosSwapsView(),
                            tag: .swaps,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label(String(localized: "menu_movements_swaps"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .accessibilityIdentifier("main-menu-movements-swaps")

                        NavigationLink(
                            destination: dependencies.makeMovimientosSearchFilterView(),
                            tag: .search,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label(String(localized: "menu_movements_search"), systemImage: "magnifyingglass")
                        }
                        .accessibilityIdentifier("main-menu-movements-search")
                    },
                    label: {
                        Label(String(localized: "menu_movements"), systemImage: "arrow.left.arrow.right")
                            .accessibilityIdentifier("main-menu-movements")
                    }
                )
                
                // Menú Administración
                DisclosureGroup(
                    isExpanded: $adminMenuIsExpanded,
                    content: {
                        NavigationLink(
                            destination: dependencies.makeAdminCryptosView(),
                            tag: .cryptos,
                            selection: $selectedAdminMenu
                        ) {
                            Label(String(localized: "menu_admin_cryptos"), systemImage: "bitcoinsign.circle")
                        }
                        .accessibilityIdentifier("main-menu-admin-cryptos")
                        
                        NavigationLink(
                            destination: dependencies.makeAdminCarterasView(),
                            tag: .carteras,
                            selection: $selectedAdminMenu
                        ) {
                            Label(String(localized: "menu_admin_wallets"), systemImage: "folder")
                        }
                        .accessibilityIdentifier("main-menu-admin-wallets")
                        
                        NavigationLink(
                            destination: dependencies.makeAdminFiatView(),
                            tag: .fiat,
                            selection: $selectedAdminMenu
                        ) {
                            Label(String(localized: "menu_admin_fiat"), systemImage: "dollarsign.circle")
                        }
                        .accessibilityIdentifier("main-menu-admin-fiat")
                        NavigationLink(
                            destination: dependencies.makeAdminPortfoliosView(),
                            tag: .portfolios,
                            selection: $selectedAdminMenu
                        ) {
                            Label(String(localized: "menu_admin_portfolios"), systemImage: "briefcase")
                        }
                        .accessibilityIdentifier("main-menu-admin-portfolios")
                        NavigationLink(
                            destination: dependencies.makeCryptoSyncView(),
                            tag: .sync,
                            selection: $selectedAdminMenu
                        ) {
                            Label(String(localized: "menu_admin_sync"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .accessibilityIdentifier("main-menu-admin-sync")
                        NavigationLink(
                            destination: dependencies.makeBackupView(),
                            tag: .backup,
                            selection: $selectedAdminMenu
                        ) {
                            Label(String(localized: "menu_admin_backup"), systemImage: "arrow.clockwise.icloud")
                        }
                        .accessibilityIdentifier("main-menu-admin-backup")
                        // Setup Inicial
                        NavigationLink(
                            destination: dependencies.makeSetupInicialView(),
                            tag: .setup,
                            selection: $selectedAdminMenu
                        ) {
                            Label(String(localized: "menu_admin_setup"), systemImage: "gearshape.circle.fill")
                        }
                        .accessibilityIdentifier("main-menu-admin-setup")
                    },
                    label: {
                        Label(String(localized: "menu_admin"), systemImage: "gear")
                            .accessibilityIdentifier("main-menu-admin")
                    }
                )
            }
            .listStyle(SidebarListStyle())
            .accessibilityIdentifier("main-sidebar")
            .navigationTitle(String(localized: "app_title"))
        } detail: {
            dependencies.makePortfolioView()
                .accessibilityIdentifier("portfolio-view")
        }
    }
    
    // MARK: - iOS (compact): TabView con Portfolio | Movimientos | Admin
    private var iosTabView: some View {
        TabView {
            NavigationStack {
                List {
                    NavigationLink {
                        dependencies.makePortfolioView()
                    } label: {
                        Label(String(localized: "menu_portfolio"), systemImage: "chart.pie.fill")
                    }
                    .accessibilityIdentifier("main-menu-portfolio")
                    
                    NavigationLink {
                        dependencies.makePortfolioPorCryptosView()
                    } label: {
                        Label(String(localized: "menu_portfolio_by_cryptos"), systemImage: "bitcoinsign.square.fill")
                    }
                    .accessibilityIdentifier("main-menu-portfolio-by-cryptos")
                    
                    NavigationLink {
                        dependencies.makePortfolioDetalleView()
                    } label: {
                        Label(String(localized: "menu_portfolio_by_wallets"), systemImage: "list.bullet.rectangle.portrait")
                    }
                    .accessibilityIdentifier("main-menu-portfolio-by-wallets")
                }
                .navigationTitle(String(localized: "tab_portfolio"))
            }
            .tabItem {
                Label(String(localized: "tab_portfolio"), systemImage: "chart.pie.fill")
            }
            .accessibilityIdentifier("tab-portfolio")
            
            NavigationStack {
                List {
                    NavigationLink {
                        dependencies.makeMovimientosEntradaView()
                    } label: {
                        Label(String(localized: "menu_movements_entry"), systemImage: "arrow.down.circle")
                    }
                    .accessibilityIdentifier("main-menu-movements-entry")
                    
                    NavigationLink {
                        dependencies.makeMovimientosSalidaView()
                    } label: {
                        Label(String(localized: "menu_movements_exit"), systemImage: "arrow.up.circle")
                    }
                    .accessibilityIdentifier("main-menu-movements-exit")
                    
                    NavigationLink {
                        dependencies.makeMovimientosEntreCarterasView()
                    } label: {
                        Label(String(localized: "menu_movements_between_wallets"), systemImage: "arrow.left.arrow.right")
                    }
                    .accessibilityIdentifier("main-menu-movements-between-wallets")
                    
                    NavigationLink {
                        dependencies.makeMovimientosSwapsView()
                    } label: {
                        Label(String(localized: "menu_movements_swaps"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityIdentifier("main-menu-movements-swaps")

                    NavigationLink {
                        dependencies.makeMovimientosSearchFilterView()
                    } label: {
                        Label(String(localized: "menu_movements_search"), systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("main-menu-movements-search")
                }
                .navigationTitle(String(localized: "tab_movements"))
            }
            .tabItem {
                Label(String(localized: "tab_movements"), systemImage: "arrow.left.arrow.right")
            }
            .accessibilityIdentifier("tab-movements")
            
            NavigationStack {
                List {
                    NavigationLink {
                        dependencies.makeAdminCryptosView()
                    } label: {
                        Label(String(localized: "menu_admin_cryptos"), systemImage: "bitcoinsign.circle")
                    }
                    .accessibilityIdentifier("main-menu-admin-cryptos")
                    
                    NavigationLink {
                        dependencies.makeAdminCarterasView()
                    } label: {
                        Label(String(localized: "menu_admin_wallets"), systemImage: "folder")
                    }
                    .accessibilityIdentifier("main-menu-admin-wallets")
                    
                    NavigationLink {
                        dependencies.makeAdminFiatView()
                    } label: {
                        Label(String(localized: "menu_admin_fiat"), systemImage: "dollarsign.circle")
                    }
                    .accessibilityIdentifier("main-menu-admin-fiat")
                    
                    NavigationLink {
                        dependencies.makeAdminPortfoliosView()
                    } label: {
                        Label(String(localized: "menu_admin_portfolios"), systemImage: "briefcase")
                    }
                    .accessibilityIdentifier("main-menu-admin-portfolios")
                    
                    NavigationLink {
                        dependencies.makeCryptoSyncView()
                    } label: {
                        Label(String(localized: "menu_admin_sync"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityIdentifier("main-menu-admin-sync")

                    NavigationLink {
                        dependencies.makeBackupView()
                    } label: {
                        Label(String(localized: "menu_admin_backup"), systemImage: "arrow.clockwise.icloud")
                    }
                    .accessibilityIdentifier("main-menu-admin-backup")

                    NavigationLink {
                        dependencies.makeSetupInicialView()
                    } label: {
                        Label(String(localized: "menu_admin_setup"), systemImage: "gearshape.circle.fill")
                    }
                    .accessibilityIdentifier("main-menu-admin-setup")
                }
                .navigationTitle(String(localized: "tab_admin"))
            }
            .tabItem {
                Label(String(localized: "tab_admin"), systemImage: "gear")
            }
            .accessibilityIdentifier("tab-admin")
        }
        .mainTabStyle()
    }
} 
