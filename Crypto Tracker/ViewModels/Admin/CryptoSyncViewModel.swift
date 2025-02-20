import SwiftUI
import SwiftData
import Combine
import Foundation

@MainActor
class CryptoSyncViewModel: ObservableObject {
    @Published private(set) var state = CryptoSyncState()
    let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Actor para manejar las tareas de forma thread-safe
    private actor TaskManager {
        private var tasks: Set<Task<Void, Never>> = []
        
        func add(_ task: Task<Void, Never>) {
            tasks.insert(task)
        }
        
        func cancelAll() {
            tasks.forEach { $0.cancel() }
            tasks.removeAll()
        }
    }
    
    private let taskManager = TaskManager()
    private var cleanupTask: Task<Void, Never>?
    
    // Cache para evitar lecturas innecesarias
    private var syncConfigCache: [UUID: CryptoSyncConfig] = [:]
    private var lastFetchTime: Date?
    private let cacheValidityInterval: TimeInterval = 300 // 5 minutos
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupInitialState()
    }
    
    private func setupInitialState() {
        loadData()
    }
    
    func loadData() {
        guard shouldRefreshCache() else { return }
        
        let cryptoDescriptor = FetchDescriptor<Crypto>(sortBy: [SortDescriptor(\.nombre)])
        let configDescriptor = FetchDescriptor<CryptoSyncConfig>(sortBy: [SortDescriptor(\.syncUrl)])
        
        do {
            state.cryptos = try modelContext.fetch(cryptoDescriptor)
            state.syncConfigs = try modelContext.fetch(configDescriptor)
            updateSyncConfigCache()
            lastFetchTime = Date()
        } catch {
            addLogEntry(cryptoSymbol: "Sistema", message: "Error cargando datos: \(error.localizedDescription)", isError: true)
        }
    }
    
    private func shouldRefreshCache() -> Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > cacheValidityInterval
    }
    
    private func updateSyncConfigCache() {
        syncConfigCache = Dictionary(
            uniqueKeysWithValues: state.syncConfigs.compactMap { config in
                guard let cryptoId = config.crypto?.id else { return nil }
                return (cryptoId, config)
            }
        )
    }
    
    func saveSyncConfig(for crypto: Crypto, url: String, defaultPrice: Decimal) {
        if let existingConfig = getSyncConfig(for: crypto.id) {
            existingConfig.syncUrl = url
            existingConfig.defaultPrice = defaultPrice
        } else {
            let newConfig = CryptoSyncConfig(crypto: crypto, syncUrl: url, defaultPrice: defaultPrice)
            modelContext.insert(newConfig)
            state.syncConfigs.append(newConfig)
            syncConfigCache[crypto.id] = newConfig
        }
        
        do {
            try modelContext.save()
        } catch {
            addLogEntry(cryptoSymbol: crypto.simbolo, message: "Error guardando configuración: \(error.localizedDescription)", isError: true)
        }
    }
    
    func getSyncConfig(for cryptoId: UUID) -> CryptoSyncConfig? {
        syncConfigCache[cryptoId] ?? state.syncConfigs.first { $0.crypto?.id == cryptoId }
    }
    
    func startSync() {
        guard !state.isSyncing else { return }
        
        state.isSyncing = true
        state.logEntries.removeAll()
        addLogEntry(cryptoSymbol: "Sistema", message: "Iniciando sincronización...", isError: false)
        
        let syncTask = Task {
            do {
                for config in state.syncConfigs {
                    guard let crypto = config.crypto else { continue }
                    if Task.isCancelled { break }
                    try await syncCrypto(crypto, with: config)
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            } catch {
                addLogEntry(cryptoSymbol: "Sistema", message: "Sincronización interrumpida", isError: true)
            }
            
            await MainActor.run {
                self.state.isSyncing = false
                addLogEntry(cryptoSymbol: "Sistema", message: "Sincronización completada", isError: false)
            }
        }
        
        Task {
            await taskManager.add(syncTask)
        }
    }
    
    private func syncCrypto(_ crypto: Crypto, with config: CryptoSyncConfig) async throws {
        do {
            let price = try await fetchPrice(from: config.syncUrl)
            await updateCryptoPrice(crypto, newPrice: price)
        } catch {
            await handleSyncError(crypto: crypto, config: config, error: error)
        }
    }
    
    private func fetchPrice(from urlString: String) async throws -> Double {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let priceResponse = try JSONDecoder().decode(PriceResponse.self, from: data)
        return priceResponse.price
    }
    
    private func updateCryptoPrice(_ crypto: Crypto, newPrice: Double) async {
        let oldPrice = crypto.precio
        let precioHistorico = PrecioHistorico(
            crypto: crypto,
            precio: oldPrice,
            fecha: crypto.ultimaActualizacion
        )
        
        modelContext.insert(precioHistorico)
        crypto.precio = Decimal(newPrice)
        crypto.ultimaActualizacion = Date()
        
        do {
            try modelContext.save()
            addLogEntry(
                cryptoSymbol: crypto.simbolo,
                message: "Precio actualizado: $\(newPrice) (anterior: $\(oldPrice))",
                isError: false
            )
        } catch {
            addLogEntry(
                cryptoSymbol: crypto.simbolo,
                message: "Error guardando precio: \(error.localizedDescription)",
                isError: true
            )
        }
    }
    
    private func handleSyncError(crypto: Crypto, config: CryptoSyncConfig, error: Error) async {
        let errorMessage = formatErrorMessage(error)
        crypto.precio = config.defaultPrice
        crypto.ultimaActualizacion = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
        
        addLogEntry(
            cryptoSymbol: crypto.simbolo,
            message: "\(errorMessage). Usando precio por defecto (\(config.defaultPrice))",
            isError: true
        )
    }
    
    private func formatErrorMessage(_ error: Error) -> String {
        switch error {
        case URLError.secureConnectionFailed:
            return "Error de conexión segura - Verifica que la URL use HTTPS"
        case URLError.serverCertificateUntrusted:
            return "Certificado del servidor no confiable"
        case URLError.networkConnectionLost:
            return "Se perdió la conexión de red"
        case URLError.badURL:
            return "URL inválida"
        case URLError.cannotConnectToHost:
            return "No se puede conectar al servidor"
        case URLError.timedOut:
            return "Tiempo de espera agotado después de 30 segundos"
        case URLError.notConnectedToInternet:
            return "No hay conexión a internet"
        case let decodingError as DecodingError:
            return "Error al procesar respuesta: \(decodingError.localizedDescription)"
        default:
            return "Error inesperado: \(error.localizedDescription)"
        }
    }
    
    private func addLogEntry(cryptoSymbol: String, message: String, isError: Bool) {
        let entry = SyncLogEntry(
            timestamp: Date(),
            cryptoSymbol: cryptoSymbol,
            message: message,
            isError: isError
        )
        state.logEntries.insert(entry, at: 0)
    }
    
    func cleanup() async {
        await taskManager.cancelAll()
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            self.state = CryptoSyncState()
            self.syncConfigCache.removeAll()
            self.cancellables.removeAll()
        }
        cleanupTask?.cancel()
        cleanupTask = nil
    }
    
    deinit {
        cleanupTask = Task { @MainActor in
            await cleanup()
        }
    }
}
