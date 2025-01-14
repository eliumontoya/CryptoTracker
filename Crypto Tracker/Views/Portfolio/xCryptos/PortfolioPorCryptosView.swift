import SwiftUI
import SwiftData

// MARK: - Vista principal del portafolio por cryptos
struct PortfolioCryptosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    
    @State private var cryptoSummaries: [CryptoPortfolioSummary] = []
    @State private var selectedCrypto: Crypto?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
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
