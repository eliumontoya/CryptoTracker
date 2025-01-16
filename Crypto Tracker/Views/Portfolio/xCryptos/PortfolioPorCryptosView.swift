import SwiftUI
import SwiftData

// MARK: - Vista principal del portafolio por cryptos
struct PortfolioCryptosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    
    @State private var cryptoSummaries: [CryptoPortfolioSummary] = []
    @State private var selectedCrypto: Crypto?
    
    //estados para los formularios de movimientos
       @State private var showingEntradaForm = false
       @State private var showingSalidaForm = false
       @State private var showingEntreCarterasForm = false
       @State private var showingSwapForm = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Header con el título y el botón
                               HStack {
                                   Text("Portafolio por Cryptos")
                                       .font(.title)
                                       .frame(maxWidth: .infinity, alignment: .leading)
                                   
                                   Menu {
                                       Button(action: { showingEntradaForm = true }) {
                                           Label("Nueva Entrada", systemImage: "arrow.down.circle")
                                       }
                                       
                                       Button(action: { showingSalidaForm = true }) {
                                           Label("Nueva Salida", systemImage: "arrow.up.circle")
                                       }
                                       
                                       Button(action: { showingEntreCarterasForm = true }) {
                                           Label("Nueva Transferencia", systemImage: "arrow.left.arrow.right")
                                       }
                                       
                                       Button(action: { showingSwapForm = true }) {
                                           Label("Nuevo Swap", systemImage: "arrow.triangle.2.circlepath")
                                       }
                                   } label: {
                                       Label("Agregar Movimiento", systemImage: "plus.circle")
                                           .font(.title2)
                                           .foregroundColor(.blue)
                                   }
                               }
                
                // Tabla de cryptos
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Encabezados de la tabla
                        CryptoPortfolioHeaderRow()
                        
                        // Filas de datos
                        ForEach(cryptoSummaries) { summary in
                            CryptoPortfolioRow(summary: summary)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCrypto = summary.crypto
                                }
                        }
                        
                        // Totales
                        if !cryptoSummaries.isEmpty {
                            Divider()
                            CryptoPortfolioTotalRow(summaries: cryptoSummaries)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding()
        }
        .navigationTitle("Portafolio por Cryptos")
        .onAppear {
            actualizarPortfolio()
        }
        .sheet(item: $selectedCrypto) { crypto in
                    CryptoDetailView(crypto: crypto)
                }
        // Sheets para los formularios de movimientos
                .sheet(isPresented: $showingEntradaForm) {
                    NavigationStack {
                        MovimientoEntradaFormView(mode: .add)
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
                .sheet(isPresented: $showingSalidaForm) {
                    NavigationStack {
                        MovimientoSalidaFormView(mode: .add)
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
                .sheet(isPresented: $showingEntreCarterasForm) {
                    NavigationStack {
                        MovimientoEntreCarterasFormView(mode: .add)
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
                .sheet(isPresented: $showingSwapForm) {
                    NavigationStack {
                        MovimientoSwapFormView(mode: .add)
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
    }
    
    private func actualizarPortfolio() {
        cryptoSummaries = PortfolioCryptoCalculator.calcularResumenPorCrypto(
            carteras: carteras,
            cryptos: cryptos
        )
    }
}

#Preview {
    PortfolioCryptosView()
        .withPreviewContainer()
}
