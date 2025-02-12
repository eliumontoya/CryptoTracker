import SwiftUI
import SwiftData
import Combine

// MARK: - Tipos de Estado del Formulario
enum FiatFormState: Identifiable {
    case add
    case edit(FIAT)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let fiat):
            return fiat.id.uuidString
        }
    }
}

// MARK: - ViewModel
@MainActor
class AdminFiatViewModel: ObservableObject {
    @Published private(set) var fiats: [FIAT] = []
    @Published var formState: FiatFormState?
    @Published var showingDeleteAlert = false
    @Published var selectedFiat: FIAT?
    
    private let modelContext: ModelContext
    private var preciosCache: [UUID: Decimal] = [:]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFiats()
    }
    
    // MARK: - Carga de Datos
    func loadFiats() {
        let descriptor = FetchDescriptor<FIAT>(sortBy: [SortDescriptor(\.nombre)])
        fiats = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Gestión de CRUD
    func addFiat(nombre: String, simbolo: String, precioUSD: Decimal) {
        let newFiat = FIAT(nombre: nombre, simbolo: simbolo, precioUSD: precioUSD)
        modelContext.insert(newFiat)
        saveContext()
        fiats.append(newFiat)
        fiats.sort { $0.nombre < $1.nombre }
    }
    
    func updateFiat(_ fiat: FIAT, nombre: String, simbolo: String, precioUSD: Decimal) {
        fiat.nombre = nombre
        fiat.simbolo = simbolo
        fiat.precioUSD = precioUSD
        saveContext()
        if let index = fiats.firstIndex(where: { $0.id == fiat.id }) {
            fiats[index] = fiat
        }
        fiats.sort { $0.nombre < $1.nombre }
        preciosCache.removeValue(forKey: fiat.id)
    }
    
    func deleteFiat(_ fiat: FIAT) {
        modelContext.delete(fiat)
        saveContext()
        fiats.removeAll { $0.id == fiat.id }
        preciosCache.removeValue(forKey: fiat.id)
    }
    
    // MARK: - Gestión del Formulario
    func showAddForm() {
        formState = .add
    }
    
    func showEditForm(for fiat: FIAT) {
        formState = .edit(fiat)
    }
    
    func closeForm() {
        formState = nil
    }
    
    // MARK: - Validaciones
    func canDeleteFiat(_ fiat: FIAT) -> Bool {
        fiat.movimientosIngreso.isEmpty && fiat.movimientosEgreso.isEmpty
    }
    
    // MARK: - Cache y Optimización
    func getPrecioUSD(_ fiat: FIAT) -> Decimal {
        if let cached = preciosCache[fiat.id] {
            return cached
        }
        preciosCache[fiat.id] = fiat.precioUSD
        return fiat.precioUSD
    }
    
    func clearCache() {
        preciosCache.removeAll()
    }
    
    private func saveContext() {
        try? modelContext.save()
    }
}
