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
    
    func actualizarPortfolio() {
        isLoading = true
        
        guard let portfolio = PortfolioQueries.defaultPortfolio(in: modelContext) else {
            carterasDetail = []
            isLoading = false
            return
        }
        
        carterasDetail = PortfolioCalculator.calcularDetallesPortfolio(
            portfolioId: portfolio.id,
            in: modelContext
        )
        isLoading = false
    }
}
