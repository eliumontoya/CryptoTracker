
import SwiftData
import SwiftUI

@Model
class CryptoSyncConfig {
    @Attribute(.unique) var id: UUID
    var crypto: Crypto?
    var syncUrl: String
    var defaultPrice: Decimal
    
    init(crypto: Crypto, syncUrl: String, defaultPrice: Decimal) {
        self.id = UUID()
        self.crypto = crypto
        self.syncUrl = syncUrl
        self.defaultPrice = defaultPrice
    }
}


