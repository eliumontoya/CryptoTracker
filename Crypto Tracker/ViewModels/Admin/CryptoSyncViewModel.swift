import SwiftUI
import SwiftData
import Foundation

@MainActor
class CryptoSyncViewModel: ObservableObject {
    @Published private(set) var state = CryptoSyncState()
    let modelContext: ModelContext
    private let priceService: PriceService

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

    private var syncConfigCache: [UUID: CryptoSyncConfig] = [:]
    private var lastFetchTime: Date?
    private let cacheValidityInterval: TimeInterval = 300

    init(modelContext: ModelContext, priceService: PriceService = CoinGeckoPriceService()) {
        self.modelContext = modelContext
        self.priceService = priceService
        setupInitialState()
    }

    private func setupInitialState() {
        loadData()
    }

    func loadData(force: Bool = false) {
        guard force || shouldRefreshCache() else { return }

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
        crypto.coingeckoId = url

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

        let syncTask = Task {
            await syncPrices()
        }

        Task {
            await taskManager.add(syncTask)
        }
    }

    func syncPrices() async {
        loadData(force: true)
        state.isSyncing = true
        state.logEntries.removeAll()
        addLogEntry(cryptoSymbol: "Sistema", message: "Iniciando sincronización...", isError: false)

        do {
            let queries = state.cryptos.compactMap { crypto -> PriceQuery? in
                guard let coingeckoId = crypto.coingeckoId, !coingeckoId.isEmpty else { return nil }
                return PriceQuery(cryptoId: crypto.id, coingeckoId: coingeckoId)
            }
            let prices = try await priceService.fetchPrices(for: queries)
            for crypto in state.cryptos {
                if Task.isCancelled { break }
                if let price = prices[crypto.id] {
                    await updateCryptoPrice(crypto, newPrice: price)
                } else {
                    await handleMissingPrice(crypto: crypto)
                }
            }
        } catch {
            addLogEntry(cryptoSymbol: "Sistema", message: "Sincronización interrumpida: \(error.localizedDescription)", isError: true)
        }

        state.isSyncing = false
        addLogEntry(cryptoSymbol: "Sistema", message: "Sincronización completada", isError: false)
    }

    private func updateCryptoPrice(_ crypto: Crypto, newPrice: Decimal) async {
        let oldPrice = crypto.precio
        let precioHistorico = PrecioHistorico(
            crypto: crypto,
            precio: oldPrice,
            fecha: crypto.ultimaActualizacion
        )

        modelContext.insert(precioHistorico)
        crypto.precio = newPrice
        crypto.ultimaActualizacion = Date()

        do {
            try modelContext.save()
            addLogEntry(
                cryptoSymbol: crypto.simbolo,
                message: "Precio actualizado: \(Format.usd(newPrice)) (anterior: \(Format.usd(oldPrice)))",
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

    private func handleMissingPrice(crypto: Crypto) async {
        if let config = getSyncConfig(for: crypto.id), config.defaultPrice > 0 {
            await updateCryptoPrice(crypto, newPrice: config.defaultPrice)
            addLogEntry(
                cryptoSymbol: crypto.simbolo,
                message: "Precio no disponible. Usando precio por defecto \(Format.usd(config.defaultPrice))",
                isError: true
            )
        } else {
            addLogEntry(
                cryptoSymbol: crypto.simbolo,
                message: "Precio no disponible: configure un CoinGecko ID y precio por defecto",
                isError: true
            )
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
        }
    }
}
