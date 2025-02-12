//
//  AdminCryptosViewModel.swift
//  Crypto Tracker
//
//  Created by Eliu Montoya on 12/02/25.
//
import SwiftUI
import SwiftData
import Combine

enum CryptoFormState: Identifiable {
    case add
    case edit(Crypto)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let crypto):
            return crypto.id.uuidString
        }
    }
}

// MARK: - ViewModel
@MainActor
class AdminCryptosViewModel: ObservableObject {
    @Published private(set) var cryptos: [Crypto] = []
    @Published var formState: CryptoFormState?
    @Published var showingDeleteAlert = false
    @Published var selectedCrypto: Crypto?
    
    private let modelContext: ModelContext
    private var calculosCache: [UUID: (precio: Decimal, ultimaActualizacion: Date)] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCryptos()
        setupObservers()
    }
    
    private func setupObservers() {
        // Observar cambios en la selección para limpiar el caché relacionado
        $selectedCrypto
            .sink { [weak self] crypto in
                if let crypto = crypto {
                    self?.calculosCache.removeValue(forKey: crypto.id)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadCryptos() {
        let descriptor = FetchDescriptor<Crypto>(sortBy: [SortDescriptor(\.nombre)])
        cryptos = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func addCrypto(nombre: String, simbolo: String, precio: Decimal) {
        let newCrypto = Crypto(nombre: nombre, simbolo: simbolo, precio: precio)
        modelContext.insert(newCrypto)
        saveContext()
        cryptos.append(newCrypto)
        cryptos.sort { $0.nombre < $1.nombre }
    }
    
    func updateCrypto(_ crypto: Crypto, nombre: String, simbolo: String, precio: Decimal) {
        // Guardar el precio anterior en el histórico
        let precioHistorico = PrecioHistorico(
            crypto: crypto,
            precio: crypto.precio,
            fecha: crypto.ultimaActualizacion
        )
        modelContext.insert(precioHistorico)
        
        // Actualizar la crypto
        crypto.nombre = nombre
        crypto.simbolo = simbolo
        crypto.precio = precio
        crypto.ultimaActualizacion = Date()
        
        saveContext()
        
        if let index = cryptos.firstIndex(where: { $0.id == crypto.id }) {
            cryptos[index] = crypto
        }
        cryptos.sort { $0.nombre < $1.nombre }
        calculosCache.removeValue(forKey: crypto.id)
    }
    
    func deleteCrypto(_ crypto: Crypto) {
        modelContext.delete(crypto)
        saveContext()
        cryptos.removeAll { $0.id == crypto.id }
        calculosCache.removeValue(forKey: crypto.id)
    }
    
    func showAddForm() {
        formState = .add
    }
    
    func showEditForm(for crypto: Crypto) {
        formState = .edit(crypto)
    }
    
    func closeForm() {
        formState = nil
    }
    
    func clearCache() {
        calculosCache.removeAll()
    }
    
    func getCalculosCrypto(_ crypto: Crypto) -> (precio: Decimal, ultimaActualizacion: Date) {
        if let cached = calculosCache[crypto.id] {
            return cached
        }
        
        let result = (crypto.precio, crypto.ultimaActualizacion)
        calculosCache[crypto.id] = result
        return result
    }
    
    private func saveContext() {
        try? modelContext.save()
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
