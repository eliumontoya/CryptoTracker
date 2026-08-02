import SwiftUI
import SwiftData
import Combine

enum CarteraFormState: Identifiable {
    case add
    case edit(Cartera)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let cartera):
            return cartera.id.uuidString
        }
    }
}

@MainActor
class AdminCarterasViewModel: ObservableObject {
    @Published private(set) var carteras: [Cartera] = []
    @Published private(set) var portfolios: [Portfolio] = []
    @Published var formState: CarteraFormState?
    @Published var showingDeleteAlert = false
    @Published var selectedCartera: Cartera?
    
    private let modelContext: ModelContext
    private var calculosCache: [UUID: (valorTotal: Decimal, resumen: String, ganancia: (Decimal, Bool))] = [:]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCarteras()
        loadPortfolios()
    }
    
    func loadCarteras() {
        let descriptor = FetchDescriptor<Cartera>(sortBy: [SortDescriptor(\.nombre)])
        carteras = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func loadPortfolios() {
        let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.nombre)])
        portfolios = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func addCartera(nombre: String, simbolo: String, portfolio: Portfolio? = nil) {
        let newCartera = Cartera(nombre: nombre, simbolo: simbolo, portfolio: portfolio)
        modelContext.insert(newCartera)
        saveContext()
        carteras.append(newCartera)
        carteras.sort { $0.nombre < $1.nombre }
    }
    
    func updateCartera(_ cartera: Cartera, nombre: String, simbolo: String, portfolio: Portfolio? = nil) {
        cartera.nombre = nombre
        cartera.simbolo = simbolo
        cartera.portfolio = portfolio
        saveContext()
        if let index = carteras.firstIndex(where: { $0.id == cartera.id }) {
            carteras[index] = cartera
        }
        carteras.sort { $0.nombre < $1.nombre }
        calculosCache.removeValue(forKey: cartera.id)
    }
    
    func toggleIsMain(_ cartera: Cartera) {
        guard let portfolio = cartera.portfolio else { return }
        let newValue = !cartera.isMain
        if newValue {
            unsetOtherMainWallets(in: portfolio, excluding: cartera)
        }
        cartera.isMain = newValue
        saveContext()
        calculosCache.removeValue(forKey: cartera.id)
        if let index = carteras.firstIndex(where: { $0.id == cartera.id }) {
            carteras[index] = cartera
        }
    }
    
    private func unsetOtherMainWallets(in portfolio: Portfolio, excluding cartera: Cartera) {
        for wallet in portfolio.carteras where wallet.isMain && wallet.id != cartera.id {
            wallet.isMain = false
            if let index = carteras.firstIndex(where: { $0.id == wallet.id }) {
                carteras[index] = wallet
            }
        }
    }
    
    func deleteCartera(_ cartera: Cartera) {
        modelContext.delete(cartera)
        saveContext()
        carteras.removeAll { $0.id == cartera.id }
        calculosCache.removeValue(forKey: cartera.id)
    }
    
    func showAddForm() {
        formState = .add
    }
    
    func showEditForm(for cartera: Cartera) {
        formState = .edit(cartera)
    }
    
    func closeForm() {
        formState = nil
    }
    
    func canDeleteCartera(_ cartera: Cartera) -> Bool {
        cartera.movimientos.isEmpty
    }
    
    func getCalculosCartera(_ cartera: Cartera) -> (valorTotal: Decimal, resumen: String, ganancia: (Decimal, Bool)) {
        if let cached = calculosCache[cartera.id] {
            return cached
        }
        
        let valorTotal = calcularValorTotalUSD(for: cartera)
        let resumen = calcularResumenCryptos(for: cartera)
        let ganancia = calcularGananciaPerdida(for: cartera)
        
        let result = (valorTotal, resumen, ganancia)
        calculosCache[cartera.id] = result
        return result
    }
    
    private func calcularValorTotalUSD(for cartera: Cartera) -> Decimal {
        let cryptos = Set(cartera.movimientos.compactMap { $0.crypto ?? $0.cryptoOrigen ?? $0.cryptoDestino })
        return cryptos.reduce(Decimal(0)) { total, crypto in
            let balance = BalanceCalculator.balance(crypto: crypto, en: cartera)
            return total + (balance * crypto.precio)
        }
    }
    
    private func calcularResumenCryptos(for cartera: Cartera) -> String {
        let cryptos = Set(cartera.movimientos.compactMap { $0.crypto ?? $0.cryptoOrigen ?? $0.cryptoDestino })
        return cryptos.compactMap { $0.simbolo }.joined(separator: ", ")
    }
    
    private func calcularGananciaPerdida(for cartera: Cartera) -> (Decimal, Bool) {
        let inversionTotalUSD = cartera.movimientos
            .filter { $0.tipo == .entrada }
            .reduce(Decimal(0)) { $0 + $1.valorTotalUSD }
        let valorActual = calcularValorTotalUSD(for: cartera)
        let gananciaPerdida = valorActual - inversionTotalUSD
        return (abs(gananciaPerdida), gananciaPerdida >= 0)
    }
    
    func clearCache() {
        calculosCache.removeAll()
    }
    
    private func saveContext() {
        try? modelContext.save()
    }
}
