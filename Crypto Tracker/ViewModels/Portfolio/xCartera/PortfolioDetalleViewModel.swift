import Foundation
import SwiftData

@MainActor
final class PortfolioDetalleViewModel: ObservableObject {
    @Published var carterasDetail: [CarteraDetail] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    var numeroRenglones: Int {
        (carterasDetail.count + 1) / 2
    }
    
    func actualizarPortfolio(carteras: [Cartera], cryptos: [Crypto], fiats: [FIAT]) {
        isLoading = true
        
        do {
            carterasDetail = PortfolioCalculator.calcularDetallesPortfolio(
                carteras: carteras,
                cryptos: cryptos,
                fiats: fiats
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
