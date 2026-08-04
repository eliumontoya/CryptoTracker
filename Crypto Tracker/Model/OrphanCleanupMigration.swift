import Foundation
import SwiftData

/// Limpieza de registros huérfanos que referencian entidades eliminadas.
///
/// Antes de que se agregaran las reglas `deleteRule: .cascade`, al borrar un
/// Crypto sus Holdings, Movimientos y Configs quedaban huérfanos. Esta
/// migración los detecta y elimina para evitar crashes al acceder a
/// relaciones invalidadas.
///
/// Es idempotente: safe to run on every launch.
@MainActor
enum OrphanCleanupMigration {
    @discardableResult
    static func apply(in context: ModelContext) -> Bool {
        // IDs válidos de Crypto
        let descriptor = FetchDescriptor<Crypto>()
        let allCryptos: [Crypto] = (try? context.fetch(descriptor)) ?? []
        let cryptoIds = Set(allCryptos.map { $0.id })

        var changed = false

        // Holdings huérfanos (crypto non-optional)
        let holdingsDesc = FetchDescriptor<Holding>()
        let holdings: [Holding] = (try? context.fetch(holdingsDesc)) ?? []
        for holding in holdings where !cryptoIds.contains(holding.crypto.id) {
            context.delete(holding)
            changed = true
        }

        // CryptoSyncConfig huérfanos
        let syncDesc = FetchDescriptor<CryptoSyncConfig>()
        let syncConfigs: [CryptoSyncConfig] = (try? context.fetch(syncDesc)) ?? []
        for config in syncConfigs where config.crypto == nil || !cryptoIds.contains(config.crypto!.id) {
            context.delete(config)
            changed = true
        }

        // Movimientos huérfanos (crypto principal)
        let movDesc = FetchDescriptor<Movimiento>()
        let movimientos: [Movimiento] = (try? context.fetch(movDesc)) ?? []
        for mov in movimientos {
            if let crypto = mov.crypto, !cryptoIds.contains(crypto.id) {
                context.delete(mov)
                changed = true
                continue
            }
            if let crypto = mov.cryptoOrigen, !cryptoIds.contains(crypto.id) {
                context.delete(mov)
                changed = true
                continue
            }
            if let crypto = mov.cryptoDestino, !cryptoIds.contains(crypto.id) {
                context.delete(mov)
                changed = true
            }
        }

        // Precios históricos huérfanos
        let precioDesc = FetchDescriptor<PrecioHistorico>()
        let precios: [PrecioHistorico] = (try? context.fetch(precioDesc)) ?? []
        for precio in precios where precio.crypto == nil || !cryptoIds.contains(precio.crypto!.id) {
            context.delete(precio)
            changed = true
        }

        if changed {
            try? context.save()
        }
        return changed
    }
}
