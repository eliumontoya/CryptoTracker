import SwiftUI
import SwiftData

enum MainMenuOption {
    case home
    case portfolioDetalle
    case administracion
    case movimientos
}

enum AdminMenuOption {
    case cryptos
    case carteras
    case fiat
}

enum MovimientosMenuOption {
    case entrada
    case salida
    case entreCarteras
    case swaps
}

struct ContentView: View {
    @State private var selectedMainMenu: MainMenuOption? = .home
    @State private var selectedAdminMenu: AdminMenuOption?
    @State private var selectedMovimientosMenu: MovimientosMenuOption?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar con menú principal
            List {
                // Opción Home
                NavigationLink(
                    destination: PortfolioView(),
                    tag: MainMenuOption.home,
                    selection: $selectedMainMenu
                ) {
                    Label("Portafolio", systemImage: "chart.pie.fill")
                }
                
                NavigationLink(
                    destination: PortfolioDetalleView(),
                    tag: MainMenuOption.portfolioDetalle,
                    selection: $selectedMainMenu
                ) {
                    Label("Desglose por Carteras", systemImage: "list.bullet.rectangle.portrait")
                }
                
                // Menú Administración
                DisclosureGroup(
                    content: {
                        NavigationLink(
                            destination: AdminCryptosView(),
                            tag: .cryptos,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Cryptos", systemImage: "bitcoinsign.circle")
                        }
                        
                        NavigationLink(
                            destination: AdminCarterasView(),
                            tag: .carteras,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Carteras", systemImage: "folder")
                        }
                        
                        NavigationLink(
                            destination: AdminFiatView(),
                            tag: .fiat,
                            selection: $selectedAdminMenu
                        ) {
                            Label("FIAT", systemImage: "dollarsign.circle")
                        }
                    },
                    label: {
                        Label("Administración", systemImage: "gear")
                    }
                )
                
                // Menú Movimientos
                DisclosureGroup(
                    content: {
                        NavigationLink(
                            destination: MovimientosEntradaView(),
                            tag: .entrada,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Entrada", systemImage: "arrow.down.circle")
                        }
                        
                        NavigationLink(
                            destination: MovimientosSalidaView(),
                            tag: .salida,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Salida", systemImage: "arrow.up.circle")
                        }
                        
                        NavigationLink(
                            destination: MovimientosEntreCarterasView(),
                            tag: .entreCarteras,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Entre Carteras", systemImage: "arrow.left.arrow.right")
                        }
                        
                        NavigationLink(
                            destination: MovimientosSwapsView(),
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
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Crypto Tracker")
        } detail: {
            PortfolioView()
        }
    }
}

#Preview {
    ContentView()
}
