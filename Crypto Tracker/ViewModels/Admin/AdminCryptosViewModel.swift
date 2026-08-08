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
    @Published private(set) var selectedCryptosForDeletion: [Crypto] = []
    @Published private(set) var deleteAlertTitle = ""
    @Published private(set) var deleteAlertMessage = ""
    @Published private(set) var deleteRequiresConfirmation = false
    @Published private(set) var formErrorMessage: String?
    
    private let modelContext: ModelContext
    private let persist: (ModelContext) throws -> Void
    private var calculosCache: [UUID: (precio: Decimal, ultimaActualizacion: Date)] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init(
        modelContext: ModelContext,
        persist: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.persist = persist
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
    
    @discardableResult
    func addCrypto(nombre: String, simbolo: String, precio: Decimal, coingeckoId: String? = nil) -> Bool {
        formErrorMessage = nil
        let newCrypto = Crypto(nombre: nombre, simbolo: simbolo, precio: precio, coingeckoId: coingeckoId)
        modelContext.insert(newCrypto)
        guard saveContext() else { return false }
        cryptos.append(newCrypto)
        cryptos.sort { $0.nombre < $1.nombre }
        return true
    }

    @discardableResult
    func updateCrypto(_ crypto: Crypto, nombre: String, simbolo: String, precio: Decimal, coingeckoId: String? = nil) -> Bool {
        formErrorMessage = nil
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
        crypto.coingeckoId = coingeckoId
        crypto.ultimaActualizacion = Date()

        guard saveContext() else { return false }

        if let index = cryptos.firstIndex(where: { $0.id == crypto.id }) {
            cryptos[index] = crypto
        }
        cryptos.sort { $0.nombre < $1.nombre }
        calculosCache.removeValue(forKey: crypto.id)
        return true
    }
    
    func requestDeletion(of candidates: [Crypto]) {
        guard !candidates.isEmpty else { return }

        selectedCryptosForDeletion = candidates
        selectedCrypto = candidates.first

        do {
            if let referencedCrypto = try candidates.first(where: { try hasBlockingReferences($0) }) {
                deleteRequiresConfirmation = false
                deleteAlertTitle = "No se puede eliminar la crypto"
                deleteAlertMessage = "\(referencedCrypto.nombre) está asociada a movimientos o holdings. Elimine esos datos primero para conservar la integridad del portafolio."
            } else {
                let cleanup = try deletionCleanupCounts(for: candidates)
                deleteRequiresConfirmation = true
                deleteAlertTitle = candidates.count == 1 ? "¿Eliminar crypto?" : "¿Eliminar \(candidates.count) cryptos?"
                if cleanup.histories + cleanup.syncConfigs > 0 {
                    deleteAlertMessage = "También se eliminarán \(cleanup.histories) históricos de precio y \(cleanup.syncConfigs) configuraciones de sincronización. Esta acción no se puede deshacer."
                } else {
                    deleteAlertMessage = "Esta acción no se puede deshacer."
                }
            }
        } catch {
            deleteRequiresConfirmation = false
            deleteAlertTitle = "No se pudo verificar la crypto"
            deleteAlertMessage = error.localizedDescription
        }

        showingDeleteAlert = true
    }

    func confirmDeletion() {
        guard deleteRequiresConfirmation else {
            clearDeletionRequest()
            return
        }

        do {
            try deleteCryptos(selectedCryptosForDeletion)
            clearDeletionRequest()
        } catch {
            modelContext.rollback()
            deleteRequiresConfirmation = false
            deleteAlertTitle = "No se pudo eliminar la crypto"
            deleteAlertMessage = error.localizedDescription
            showingDeleteAlert = true
        }
    }

    func cancelDeletion() {
        clearDeletionRequest()
    }

    func showAddForm() {
        formState = .add
    }
    
    func showEditForm(for crypto: Crypto) {
        formState = .edit(crypto)
    }
    
    func closeForm() {
        formErrorMessage = nil
        formState = nil
    }

    func clearFormError() {
        formErrorMessage = nil
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
    
    private func deleteCryptos(_ values: [Crypto]) throws {
        let ids = Set(values.map(\.id))
        let histories = try modelContext.fetch(FetchDescriptor<PrecioHistorico>())
        let syncConfigs = try modelContext.fetch(FetchDescriptor<CryptoSyncConfig>())
        histories.filter { history in
            guard let cryptoId = history.crypto?.id else { return false }
            return ids.contains(cryptoId)
        }.forEach(modelContext.delete)
        syncConfigs.filter { config in
            guard let cryptoId = config.crypto?.id else { return false }
            return ids.contains(cryptoId)
        }.forEach(modelContext.delete)
        values.forEach(modelContext.delete)
        try persist(modelContext)

        cryptos.removeAll { ids.contains($0.id) }
        ids.forEach { calculosCache.removeValue(forKey: $0) }
    }

    private func hasBlockingReferences(_ crypto: Crypto) throws -> Bool {
        if !crypto.movimientos.isEmpty ||
            !crypto.movimientosComoCryptoOrigen.isEmpty ||
            !crypto.movimientosComoCryptoDestino.isEmpty {
            return true
        }

        let holdings = try modelContext.fetch(FetchDescriptor<Holding>())
        if holdings.contains(where: { $0.crypto.id == crypto.id }) {
            return true
        }

        return false
    }

    private func deletionCleanupCounts(for cryptos: [Crypto]) throws -> (histories: Int, syncConfigs: Int) {
        let ids = Set(cryptos.map(\.id))
        let histories = try modelContext.fetch(FetchDescriptor<PrecioHistorico>())
            .filter { history in
                guard let cryptoId = history.crypto?.id else { return false }
                return ids.contains(cryptoId)
            }.count
        let syncConfigs = try modelContext.fetch(FetchDescriptor<CryptoSyncConfig>())
            .filter { config in
                guard let cryptoId = config.crypto?.id else { return false }
                return ids.contains(cryptoId)
            }.count
        return (histories, syncConfigs)
    }

    private func clearDeletionRequest() {
        selectedCrypto = nil
        selectedCryptosForDeletion = []
        deleteRequiresConfirmation = false
        showingDeleteAlert = false
    }

    @discardableResult
    private func saveContext() -> Bool {
        do {
            try persist(modelContext)
            return true
        } catch {
            modelContext.rollback()
            formErrorMessage = error.localizedDescription
            return false
        }
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
