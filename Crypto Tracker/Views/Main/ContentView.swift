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
    case setup  //  caso para Setup Inicial
}

enum MovimientosMenuOption {
    case entrada
    case salida
    case entreCarteras
    case swaps
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
                    destination: dependencies.makePortfolioView(),
                    tag: MainMenuOption.home,
                    selection: $selectedMainMenu
                ) {
                    Label("Portafolio", systemImage: "chart.pie.fill")
                }
                
                NavigationLink(
                    destination: dependencies.makePortfolioPorCryptosView(),
                    tag: MainMenuOption.portfolioCryptos,
                    selection: $selectedMainMenu
                ) {
                    Label("Portafolio por Cryptos", systemImage: "bitcoinsign.square.fill")
                }
                
                NavigationLink(
                    destination: dependencies.makePortfolioDetalleView(),
                    tag: MainMenuOption.portfolioDetalle,
                    selection: $selectedMainMenu
                ) {
                    Label("Desglose por Carteras", systemImage: "list.bullet.rectangle.portrait")
                }
                
                // Menú Movimientos
                DisclosureGroup(
                    content: {
                        NavigationLink(
                            destination: dependencies.makeMovimientosEntradaView(),
                            tag: .entrada,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Entrada", systemImage: "arrow.down.circle")
                        }
                        
                        NavigationLink(
                            destination: dependencies.makeMovimientosSalidaView(),
                            tag: .salida,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Salida", systemImage: "arrow.up.circle")
                        }
                        
                        NavigationLink(
                            destination: dependencies.makeMovimientosEntreCarterasView(),
                            tag: .entreCarteras,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Entre Carteras", systemImage: "arrow.left.arrow.right")
                        }
                        
                        NavigationLink(
                            destination: dependencies.makeMovimientosSwapsView(),
                            tag: .swaps,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Swaps", systemImage: "arrow.triangle.2.circlepath")
                        }
                    },
                    label: {
                        Label("Movimientos", systemImage: "arrow.left.right")
                    }
                )
                
                // Menú Administración
                DisclosureGroup(
                    content: {
                        NavigationLink(
                            destination: dependencies.makeAdminCryptosView(),
                            tag: .cryptos,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Cryptos", systemImage: "bitcoinsign.circle")
                        }
                        
                        NavigationLink(
                            destination: dependencies.makeAdminCarterasView(),
                            tag: .carteras,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Carteras", systemImage: "folder")
                        }
                        
                        NavigationLink(
                            destination: dependencies.makeAdminFiatView(),
                            tag: .fiat,
                            selection: $selectedAdminMenu
                        ) {
                            Label("FIAT", systemImage: "dollarsign.circle")
                        }
                        NavigationLink(
                            destination: dependencies.makeAdminPortfoliosView(),
                            tag: .portfolios,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Portfolios", systemImage: "briefcase")
                        }
                        NavigationLink(
                            destination: dependencies.makeCryptoSyncView(),
                            tag: .sync,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Sync Manual de Precios", systemImage: "arrow.triangle.2.circlepath")
                        }
                        // Setup Inicial
                        NavigationLink(
                            destination: dependencies.makeSetupInicialView(),
                            tag: .setup,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Setup Inicial", systemImage: "gearshape.circle.fill")
                        }
                    },
                    label: {
                        Label("Administración", systemImage: "gear")
                    }
                )
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Crypto Tracker")
        } detail: {
            dependencies.makePortfolioView()
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
                        Label("Portafolio", systemImage: "chart.pie.fill")
                    }
                    
                    NavigationLink {
                        dependencies.makePortfolioPorCryptosView()
                    } label: {
                        Label("Portafolio por Cryptos", systemImage: "bitcoinsign.square.fill")
                    }
                    
                    NavigationLink {
                        dependencies.makePortfolioDetalleView()
                    } label: {
                        Label("Desglose por Carteras", systemImage: "list.bullet.rectangle.portrait")
                    }
                }
                .navigationTitle("Portfolio")
            }
            .tabItem {
                Label("Portfolio", systemImage: "chart.pie.fill")
            }
            
            NavigationStack {
                List {
                    NavigationLink {
                        dependencies.makeMovimientosEntradaView()
                    } label: {
                        Label("Entrada", systemImage: "arrow.down.circle")
                    }
                    
                    NavigationLink {
                        dependencies.makeMovimientosSalidaView()
                    } label: {
                        Label("Salida", systemImage: "arrow.up.circle")
                    }
                    
                    NavigationLink {
                        dependencies.makeMovimientosEntreCarterasView()
                    } label: {
                        Label("Entre Carteras", systemImage: "arrow.left.arrow.right")
                    }
                    
                    NavigationLink {
                        dependencies.makeMovimientosSwapsView()
                    } label: {
                        Label("Swaps", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .navigationTitle("Movimientos")
            }
            .tabItem {
                Label("Movimientos", systemImage: "arrow.left.right")
            }
            
            NavigationStack {
                List {
                    NavigationLink {
                        dependencies.makeAdminCryptosView()
                    } label: {
                        Label("Cryptos", systemImage: "bitcoinsign.circle")
                    }
                    
                    NavigationLink {
                        dependencies.makeAdminCarterasView()
                    } label: {
                        Label("Carteras", systemImage: "folder")
                    }
                    
                    NavigationLink {
                        dependencies.makeAdminFiatView()
                    } label: {
                        Label("FIAT", systemImage: "dollarsign.circle")
                    }
                    
                    NavigationLink {
                        dependencies.makeAdminPortfoliosView()
                    } label: {
                        Label("Portfolios", systemImage: "briefcase")
                    }
                    
                    NavigationLink {
                        dependencies.makeCryptoSyncView()
                    } label: {
                        Label("Sync Manual de Precios", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    NavigationLink {
                        dependencies.makeSetupInicialView()
                    } label: {
                        Label("Setup Inicial", systemImage: "gearshape.circle.fill")
                    }
                }
                .navigationTitle("Admin")
            }
            .tabItem {
                Label("Admin", systemImage: "gear")
            }
        }
    }
} 
