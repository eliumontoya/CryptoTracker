import SwiftUI
import SwiftData

struct PortfolioDetalleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var carterasDetail: [CarteraDetail] = []
    
    // Calcular cuántos renglones necesitamos (2 carteras por renglón)
    private var numeroRenglones: Int {
        (carterasDetail.count + 1) / 2
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<numeroRenglones, id: \.self) { renglon in
                    HStack(alignment: .top, spacing: 20) {
                        // Primera columna del renglón
                        if renglon * 2 < carterasDetail.count {
                            CarteraDetailView(carteraDetail: carterasDetail[renglon * 2])
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Segunda columna del renglón
                        if (renglon * 2 + 1) < carterasDetail.count {
                            CarteraDetailView(carteraDetail: carterasDetail[renglon * 2 + 1])
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Desglose por Carteras")
        .onAppear {
            actualizarPortfolio()
        }
    }
    
    private func actualizarPortfolio() {
        carterasDetail = PortfolioCalculator.calcularDetallesPortfolio(
            carteras: carteras,
            cryptos: cryptos,
            fiats: fiats
        )
    }
}

#Preview {
    PortfolioDetalleView()
        .withPreviewContainer()
}
