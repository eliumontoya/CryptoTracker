import Foundation
import SwiftData

// MARK: - Values

/// Editable fields of an entry movement (`.entrada`). A value payload is used so
/// the use case can persist every field the entrada form exposes without the
/// caller reaching into the entity.
struct EditMovementValues {
    let fecha: Date
    let cantidadCrypto: Decimal
    let precioUSD: Decimal
    let valorTotalUSD: Decimal
    let usaFiatAlterno: Bool
    let precioFiatAlterno: Decimal?
    let valorTotalFiatAlterno: Decimal?
    let crypto: Crypto
    let cartera: Cartera
    let fiatAlterno: FIAT?
}

// MARK: - Input

/// Input for editing an existing entry movement.
///
/// Contract: `movement` MUST still hold the pre-edit values when `execute` is
/// called — the use case snapshots them (`HoldingServiceProtocol.snapshot`) as
/// the revert basis, so any earlier mutation of the entity would corrupt the
/// holding adjustment.
struct EditMovementInput {
    let movement: Movimiento
    let updated: EditMovementValues
}

// MARK: - Error

/// Domain errors for entry-movement editing.
enum EditMovementError: Error, LocalizedError {
    /// Reverting the previous quantity would drive the old holding below zero.
    case insufficientHoldings
    /// The use case only supports `.entrada` movements.
    case unsupportedMovementType

    var errorDescription: String? {
        switch self {
        case .insufficientHoldings:
            return "La edición dejaría la cartera con saldo negativo"
        case .unsupportedMovementType:
            return "Este tipo de movimiento no se puede editar como entrada"
        }
    }
}

// MARK: - Protocol

/// Edits an existing entry movement and adjusts the associated holding in one
/// atomic transaction: the previous holding effect is reverted and the new one
/// applied, so the materialized `Holding` rows stay in sync with the movement.
protocol EditMovementUseCaseProtocol {
    func execute(_ input: EditMovementInput) async throws
}

// MARK: - Implementation

struct EditMovementUseCase: EditMovementUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    func execute(_ input: EditMovementInput) async throws {
        // Old state: snapshot BEFORE mutation so the edit can revert the
        // previously applied holding effect and apply the new one.
        let previous = holdingService.snapshot(of: input.movement)

        try await transactionRunner.run { context in
            try validateRevert(previous: previous, in: context)
            apply(input.updated, to: input.movement)
            try holdingService.updateHoldingForMovement(input.movement, previous: previous, in: context)
        }
    }

    // MARK: - Mutation

    private func apply(_ values: EditMovementValues, to movement: Movimiento) {
        movement.fecha = values.fecha
        movement.cantidadCrypto = values.cantidadCrypto
        movement.precioUSD = values.precioUSD
        movement.valorTotalUSD = values.valorTotalUSD
        movement.usaFiatAlterno = values.usaFiatAlterno
        movement.precioFiatAlterno = values.precioFiatAlterno
        movement.valorTotalFiatAlterno = values.valorTotalFiatAlterno
        movement.cartera = values.cartera
        movement.crypto = values.crypto
        movement.fiatAlterno = values.fiatAlterno
    }

    // MARK: - Validation

    /// For an `.entrada`, the revert subtracts the previous quantity from the
    /// holding it created. `Holding.cantidad` clamps silently at zero, so the
    /// use case fails fast with an explicit error instead of corrupting the
    /// balance (e.g. after later sales consumed the entry's holdings).
    private func validateRevert(previous: HoldingSnapshot, in context: ModelContext) throws {
        guard previous.tipo == .entrada else {
            throw EditMovementError.unsupportedMovementType
        }
        guard let cartera = try fetchCartera(id: previous.carteraId, in: context),
              let crypto = try fetchCrypto(id: previous.cryptoId, in: context) else { return }
        // Legacy wallets without a portfolio cannot own a materialized holding row.
        guard let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else { return }

        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        guard let holding = try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first else { return }

        guard holding.cantidad - previous.cantidadCrypto >= 0 else {
            throw EditMovementError.insufficientHoldings
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
