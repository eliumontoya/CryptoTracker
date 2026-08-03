import Foundation

// MARK: - Log Entry Model
struct SyncLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cryptoSymbol: String
    let message: String
    let isError: Bool
}

// MARK: - View State
struct CryptoSyncState {
    var cryptos: [Crypto] = []
    var syncConfigs: [CryptoSyncConfig] = []
    var logEntries: [SyncLogEntry] = []
    var isSyncing = false
}
