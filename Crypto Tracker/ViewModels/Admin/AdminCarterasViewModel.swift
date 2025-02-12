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
class AdminCarterasViewModel: ObservableObject {
    @Published private(set) var carteras: [Cartera] = []
    @Published var formState: CarteraFormState?
    @Published var showingDeleteAlert = false
    @Published var selectedCartera: Cartera?
    
    private let modelContext: ModelContext
    private var calculosCache: [UUID: (valorTotal: Decimal, resumen: String, ganancia: (Decimal, Bool))] = [:]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCarteras()
    }
    
    func loadCarteras() {
        let descriptor = FetchDescriptor<Cartera>(sortBy: [SortDescriptor(\.nombre)])
        carteras = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func addCartera(nombre: String, simbolo: String) {
        let newCartera = Cartera(nombre: nombre, simbolo: simbolo)
        modelContext.insert(newCartera)
        saveContext()
        carteras.append(newCartera)
        carteras.sort { $0.nombre < $1.nombre }
    }
    
    func updateCartera(_ cartera: Cartera, nombre: String, simbolo: String) {
        cartera.nombre = nombre
        cartera.simbolo = simbolo
        saveContext()
        if let index = carteras.firstIndex(where: { $0.id == cartera.id }) {
            carteras[index] = cartera
        }
        carteras.sort { $0.nombre < $1.nombre }
        calculosCache.removeValue(forKey: cartera.id)
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
        cartera.movimientosIngreso.isEmpty &&
        cartera.movimientosEgreso.isEmpty &&
        cartera.movimientosEntrada.isEmpty &&
        cartera.movimientosSalida.isEmpty &&
        cartera.swaps.isEmpty
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
        let cryptos = Set(cartera.movimientosIngreso.compactMap { $0.crypto })
        return cryptos.reduce(Decimal(0)) { total, crypto in
            let balance = calcularBalanceCrypto(crypto, en: cartera)
            return total + (balance * crypto.precio)
        }
    }
    
    private func calcularResumenCryptos(for cartera: Cartera) -> String {
        let cryptos = Set(cartera.movimientosIngreso.compactMap { $0.crypto })
        return cryptos.compactMap { $0.simbolo }.joined(separator: ", ")
    }
    
    private func calcularGananciaPerdida(for cartera: Cartera) -> (Decimal, Bool) {
        let inversionTotalUSD = cartera.movimientosIngreso.reduce(Decimal(0)) { $0 + $1.valorTotalUSD }
        let valorActual = calcularValorTotalUSD(for: cartera)
        let gananciaPerdida = valorActual - inversionTotalUSD
        return (abs(gananciaPerdida), gananciaPerdida >= 0)
    }
    
    private func calcularBalanceCrypto(_ crypto: Crypto, en cartera: Cartera) -> Decimal {
        let ingresos = cartera.movimientosIngreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
        
        let egresos = cartera.movimientosEgreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
        
        let transferenciasEntrada = cartera.movimientosEntrada
            .filter { $0.crypto?.id == crypto.id }
            .reduce(Decimal(0)) { $0 + $1.cantidadCryptoEntrada }
        
        let transferenciasSalida = cartera.movimientosSalida
            .filter { $0.crypto?.id == crypto.id }
            .reduce(Decimal(0)) { $0 + $1.cantidadCryptoSalida }
        
        let swapsEntrada = cartera.swaps
            .filter { $0.cryptoDestino?.id == crypto.id }
            .reduce(Decimal(0)) { $0 + $1.cantidadDestino }
        
        let swapsSalida = cartera.swaps
            .filter { $0.cryptoOrigen?.id == crypto.id }
            .reduce(Decimal(0)) { $0 + $1.cantidadOrigen }
        
        return ingresos + transferenciasEntrada + swapsEntrada -
               (egresos + transferenciasSalida + swapsSalida)
    }
    
    func clearCache() {
        calculosCache.removeAll()
    }
    
    private func saveContext() {
        try? modelContext.save()
    }
}
