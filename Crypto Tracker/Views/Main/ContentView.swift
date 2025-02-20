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
    @Environment(\.modelContext) private var modelContext

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
                    destination: PortfolioPorCryptosView(),
                    tag: MainMenuOption.portfolioCryptos,
                    selection: $selectedMainMenu
                ) {
                    Label("Portafolio por Cryptos", systemImage: "bitcoinsign.square.fill")
                }
                 
                NavigationLink(
                    destination: PortfolioDetalleView(),
                    tag: MainMenuOption.portfolioDetalle,
                    selection: $selectedMainMenu
                ) {
                    Label("Desglose por Carteras", systemImage: "list.bullet.rectangle.portrait")
                }
         
                  
               
                // Menú Movimientos
                DisclosureGroup(
                    content: {
                        NavigationLink(
                                                    destination: MovimientosEntradaView(
                                                        viewModel: MovimientoEntradaViewModel(
                                                            modelContext: modelContext
                                                        )
                                                    ),
                                                    tag: .entrada,
                                                    selection: $selectedMovimientosMenu
                                                ) {
                                                    Label("Entrada", systemImage: "arrow.down.circle")
                                                }
                        
                        
                        NavigationLink(
                            destination: MovimientosSalidaView()
                                .environment(\.modelContext, modelContext),
                            tag: .salida,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Salida", systemImage: "arrow.up.circle")
                        }
                        
                        NavigationLink(
                            destination: MovimientosEntreCarterasView()
                                .environment(\.modelContext, modelContext),
                            tag: .entreCarteras,
                            selection: $selectedMovimientosMenu
                        ) {
                            Label("Entre Carteras", systemImage: "arrow.left.arrow.right")
                        }
                        
                        NavigationLink(
                            destination: MovimientosSwapsView()
                                .environment(\.modelContext, modelContext),
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
                            destination: AdminCryptosView(modelContext: modelContext),
                            tag: .cryptos,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Cryptos", systemImage: "bitcoinsign.circle")
                        }
                        
                        NavigationLink(
                            destination: AdminCarterasView(modelContext: modelContext),
                            tag: .carteras,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Carteras", systemImage: "folder")
                        }
                        
                        NavigationLink(
                            destination: AdminFiatView(modelContext: modelContext),
                            tag: .fiat,
                            selection: $selectedAdminMenu
                        ) {
                            Label("FIAT", systemImage: "dollarsign.circle")
                        }
                        NavigationLink(
                            destination: CryptoSyncView()
                                                           .environment(\.modelContext, modelContext),
                            tag: .sync,
                            selection: $selectedAdminMenu
                        ) {
                            Label("Sync Manual de Precios", systemImage: "arrow.triangle.2.circlepath")
                        }
                        // Setup Inicial
                        NavigationLink(
                                                    destination: SetupInicialView(),
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
           // PortfolioView()
        }
    }
}

#Preview {
    ContentView()
}
