import Foundation
import SwiftData

// MARK: - Snapshot

/// Snapshot of a movement's holding-affecting fields, captured BEFORE mutation so an
/// edit can revert the previously applied effect and apply the new one.
struct HoldingSnapshot: Equatable {
    let tipo: TipoMovimiento
    let carteraId: UUID?
    let carteraOrigenId: UUID?
    let carteraDestinoId: UUID?
    let cryptoId: UUID?
    let cryptoOrigenId: UUID?
    let cryptoDestinoId: UUID?
    let cantidadCrypto: Decimal
    let cantidadCryptoSalida: Decimal
    let cantidadCryptoEntrada: Decimal
    let cantidadOrigen: Decimal
    let cantidadDestino: Decimal

    init(movement: Movimiento) {
        self.tipo = movement.tipo
        self.carteraId = movement.cartera?.id
        self.carteraOrigenId = movement.carteraOrigen?.id
        self.carteraDestinoId = movement.carteraDestino?.id
        self.cryptoId = movement.crypto?.id
        self.cryptoOrigenId = movement.cryptoOrigen?.id
        self.cryptoDestinoId = movement.cryptoDestino?.id
        self.cantidadCrypto = movement.cantidadCrypto
        self.cantidadCryptoSalida = movement.cantidadCryptoSalida
        self.cantidadCryptoEntrada = movement.cantidadCryptoEntrada
        self.cantidadOrigen = movement.cantidadOrigen
        self.cantidadDestino = movement.cantidadDestino
    }
}

// MARK: - Protocol

/// Maintains the materialized `Holding` rows so the dashboard KPIs (CQRS read layer)
/// stay in sync with every movement change. Mutations happen on the injected
/// `ModelContext` and are meant to run inside a `TransactionRunner` block, so the
/// movement change and its holding update persist (or roll back) atomically.
protocol HoldingServiceProtocol {
    /// Applies a movement's effect to the holdings (create path).
    func updateHoldingForMovement(_ movement: Movimiento, in context: ModelContext) throws
    /// Reverts `previous` and applies the movement's new effect (edit path).
    func updateHoldingForMovement(_ movement: Movimiento, previous: HoldingSnapshot, in context: ModelContext) throws
    /// Reverts a movement's effect on the holdings (delete path).
    func deleteHoldingForMovement(_ movement: Movimiento, in context: ModelContext) throws
    /// Captures the holding-affecting fields of a movement before mutation.
    func snapshot(of movement: Movimiento) -> HoldingSnapshot
}

// MARK: - Implementation

struct HoldingService: HoldingServiceProtocol {
    func updateHoldingForMovement(_ movement: Movimiento, in context: ModelContext) throws {
        let deltas = try deltas(for: HoldingSnapshot(movement: movement), in: context)
        try apply(deltas, in: context)
    }

    func updateHoldingForMovement(_ movement: Movimiento, previous: HoldingSnapshot, in context: ModelContext) throws {
        let oldDeltas = try deltas(for: previous, in: context)
        try apply(oldDeltas.map { $0.inverted() }, in: context)
        let newDeltas = try deltas(for: HoldingSnapshot(movement: movement), in: context)
        try apply(newDeltas, in: context)
    }

    func deleteHoldingForMovement(_ movement: Movimiento, in context: ModelContext) throws {
        let deltas = try deltas(for: HoldingSnapshot(movement: movement), in: context)
        try apply(deltas.map { $0.inverted() }, in: context)
    }

    func snapshot(of movement: Movimiento) -> HoldingSnapshot {
        HoldingSnapshot(movement: movement)
    }

    // MARK: - Delta computation

    /// A signed change applied to one materialized holding row.
    private struct HoldingDelta {
        let cartera: Cartera
        let crypto: Crypto
        let delta: Decimal
        /// `true` for `.ajuste`: the row is set to `delta` (absolute) instead of incremented.
        let isAbsolute: Bool

        func inverted() -> HoldingDelta {
            HoldingDelta(cartera: cartera, crypto: crypto, delta: -delta, isAbsolute: false)
        }
    }

    private func deltas(for snapshot: HoldingSnapshot, in context: ModelContext) throws -> [HoldingDelta] {
        switch snapshot.tipo {
        case .entrada:
            guard let cartera = try fetchCartera(id: snapshot.carteraId, in: context),
                  let crypto = try fetchCrypto(id: snapshot.cryptoId, in: context) else { return [] }
            return [HoldingDelta(cartera: cartera, crypto: crypto, delta: snapshot.cantidadCrypto, isAbsolute: false)]

        case .salida:
            guard let cartera = try fetchCartera(id: snapshot.carteraId, in: context),
                  let crypto = try fetchCrypto(id: snapshot.cryptoId, in: context) else { return [] }
            return [HoldingDelta(cartera: cartera, crypto: crypto, delta: -snapshot.cantidadCrypto, isAbsolute: false)]

        case .transferenciaSalida:
            guard let cartera = try fetchCartera(id: snapshot.carteraOrigenId, in: context),
                  let crypto = try fetchCrypto(id: snapshot.cryptoId, in: context) else { return [] }
            return [HoldingDelta(cartera: cartera, crypto: crypto, delta: -snapshot.cantidadCryptoSalida, isAbsolute: false)]

        case .transferenciaEntrada:
            guard let cartera = try fetchCartera(id: snapshot.carteraDestinoId, in: context),
                  let crypto = try fetchCrypto(id: snapshot.cryptoId, in: context) else { return [] }
            return [HoldingDelta(cartera: cartera, crypto: crypto, delta: snapshot.cantidadCryptoEntrada, isAbsolute: false)]

        case .swapSalida:
            guard let cartera = try fetchCartera(id: snapshot.carteraId, in: context),
                  let crypto = try fetchCrypto(id: snapshot.cryptoOrigenId, in: context) else { return [] }
            return [HoldingDelta(cartera: cartera, crypto: crypto, delta: -snapshot.cantidadOrigen, isAbsolute: false)]

        case .swapEntrada:
            guard let cartera = try fetchCartera(id: snapshot.carteraId, in: context),
                  let crypto = try fetchCrypto(id: snapshot.cryptoDestinoId, in: context) else { return [] }
            return [HoldingDelta(cartera: cartera, crypto: crypto, delta: snapshot.cantidadDestino, isAbsolute: false)]

        case .ajuste:
            guard let cartera = try fetchCartera(id: snapshot.carteraId, in: context),
                  let crypto = try fetchCrypto(id: snapshot.cryptoId, in: context) else { return [] }
            return [HoldingDelta(cartera: cartera, crypto: crypto, delta: snapshot.cantidadCrypto, isAbsolute: true)]

        case .comision:
            // Fees do not move holdings: the commission is already netted in the
            // transferencia amounts (cantidadCryptoComision = salida - entrada).
            return []
        }
    }

    // MARK: - Application

    private func apply(_ deltas: [HoldingDelta], in context: ModelContext) throws {
        for delta in deltas {
            guard let portfolio = delta.cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else {
                // Legacy wallets without a portfolio cannot own a materialized holding;
                // skip the write instead of failing the whole transaction.
                continue
            }
            let key = Holding.makeId(portfolio: portfolio, cartera: delta.cartera, crypto: delta.crypto)
            let existing = try context.fetch(
                FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
            ).first

            if delta.isAbsolute {
                if delta.delta <= 0 {
                    if let existing { context.delete(existing) }
                } else if let existing {
                    existing.cantidad = delta.delta
                    existing.updatedAt = Date()
                } else {
                    context.insert(Holding(portfolio: portfolio, cartera: delta.cartera, crypto: delta.crypto, cantidad: delta.delta))
                }
            } else if let existing {
                let newQty = existing.cantidad + delta.delta
                if newQty <= 0 {
                    context.delete(existing)
                } else {
                    existing.cantidad = newQty
                    existing.updatedAt = Date()
                }
            } else if delta.delta > 0 {
                context.insert(Holding(portfolio: portfolio, cartera: delta.cartera, crypto: delta.crypto, cantidad: delta.delta))
            }
        }
    }

    // MARK: - Lookups

    private func fetchCartera(id: UUID?, in context: ModelContext) throws -> Cartera? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Cartera>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchCrypto(id: UUID?, in context: ModelContext) throws -> Crypto? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Crypto>(predicate: #Predicate { $0.id == id })).first
    }
}
