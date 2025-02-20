import Foundation

// MARK: - Log Entry Model
struct SyncLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cryptoSymbol: String
    let message: String
    let isError: Bool
}

// MARK: - Price Response Model
struct PriceResponse: Codable {
    let price: Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Buscar cualquier clave en el primer nivel
        guard let firstKey = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No se encontró ninguna clave"))
        }
        
        // Obtener el contenido del primer objeto
        let innerContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: firstKey)
        
        // Buscar el valor USD
        guard let usdValue = try? innerContainer.decode(Double.self, forKey: DynamicCodingKeys(stringValue: "usd")!) else {
            throw DecodingError.keyNotFound(DynamicCodingKeys(stringValue: "usd")!,
                .init(codingPath: [], debugDescription: "No se encontró el precio USD"))
        }
        
        self.price = usdValue
    }
    
    // Claves dinámicas para decodificación
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
}

// MARK: - View State
struct CryptoSyncState {
    var cryptos: [Crypto] = []
    var syncConfigs: [CryptoSyncConfig] = []
    var logEntries: [SyncLogEntry] = []
    var isSyncing = false
}
