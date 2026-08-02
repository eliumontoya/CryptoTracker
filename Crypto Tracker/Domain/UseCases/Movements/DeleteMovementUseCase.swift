import Foundation
import SwiftData

// MARK: - Errors

/// Errors thrown by `DeleteMovementUseCase`. The use case is scoped to entry
/// movements (issue #39): the revert formula for other types differs.
enum DeleteMovementError: LocalizedError, Equatable {
    case unsupportedMovementType(TipoMovimiento)
    case insufficientHoldings

    var errorDescription: String? {
        switch self {
        case .unsupportedMovementType(let tipo):
            return "Solo se puede eliminar un movimiento de entrada. Tipo recibido: \(tipo.title)."
        case .insufficientHoldings:
            return "No se puede eliminar el movimiento: revertirlo dejaría el saldo de la cartera en negativo."
        }
    }
}

// MARK: - Protocol

/// Physically deletes an entry movement and reverts its holding atomically.
protocol DeleteMovementUseCaseProtocol {
    func delete(_ movement: Movimiento) async throws
}

// MARK: - Implementation

/// Deletes a movement and its holding effect in one `TransactionRunner` block:
/// 1. Pre-validates that reverting the movement's effect keeps the materialized
///    `Holding` non-negative (domain invariant, issue #39).
/// 2. Reverts the holding via `HoldingServiceProtocol.deleteHoldingForMovement`.
/// 3. Physically deletes the movement (`context.delete`).
///
/// Any failure rolls back the whole block, so movement + holding stay consistent.
struct DeleteMovementUseCase: DeleteMovementUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    func delete(_ movement: Movimiento) async throws {
        try await transactionRunner.run { context in
            try validateRevert(of: movement, in: context)
            try holdingService.deleteHoldingForMovement(movement, in: context)
            context.delete(movement)
        }
    }

    // MARK: - Validation

    /// Reject deletes that would drive any affected holding below zero.
    ///
    /// For an `.entrada` the revert subtracts `cantidadCrypto` from the current
    /// holding, so the current row must cover it. `Holding.cantidad` clamps at 0
    /// via `didSet`, hence the guard must run BEFORE the revert to surface the
    /// violation as an error instead of silently erasing the row.
    private func validateRevert(of movement: Movimiento, in context: ModelContext) throws {
        guard movement.tipo == .entrada else {
            throw DeleteMovementError.unsupportedMovementType(movement.tipo)
        }
        // Legacy wallets without a portfolio cannot own a materialized holding
        // (mirrors `HoldingService.apply`'s guard) — nothing to validate.
        guard movement.cartera?.portfolio != nil || PortfolioQueries.defaultPortfolio(in: context) != nil else {
            return
        }
        let current = try holdingRow(for: movement, in: context)?.cantidad ?? 0
        guard current - movement.cantidadCrypto >= 0 else {
            throw DeleteMovementError.insufficientHoldings
        }
    }

    private func holdingRow(for movement: Movimiento, in context: ModelContext) throws -> Holding? {
        guard let cartera = movement.cartera, let crypto = movement.crypto else { return nil }
        guard let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else { return nil }
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }
}
