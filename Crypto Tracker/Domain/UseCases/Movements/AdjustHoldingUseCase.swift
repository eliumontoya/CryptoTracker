import Foundation
import SwiftData

// MARK: - Input

/// Values needed to manually adjust a materialized holding to a new absolute quantity.
/// The adjustment is persisted as a `.ajuste` movement so the ledger stays auditable.
struct AdjustHoldingInput {
    let fecha: Date
    let portfolio: Portfolio
    let cartera: Cartera
    let crypto: Crypto
    let cantidad: Decimal
    let motivo: String?
}

// MARK: - Errors

/// Errors thrown by `AdjustHoldingUseCase`.
enum AdjustHoldingError: Error, LocalizedError, Equatable {
    /// The requested adjustment quantity is negative.
    case invalidQuantity

    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "La cantidad de ajuste no puede ser negativa."
        }
    }
}

// MARK: - Protocol

/// Manually adjusts a holding to an absolute quantity and records a `.ajuste`
/// movement atomically inside a single `TransactionRunner` block.
protocol AdjustHoldingUseCaseProtocol {
    @discardableResult
    func execute(_ input: AdjustHoldingInput) async throws -> Movimiento
}

// MARK: - Implementation

struct AdjustHoldingUseCase: AdjustHoldingUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    @discardableResult
    func execute(_ input: AdjustHoldingInput) async throws -> Movimiento {
        guard input.cantidad >= 0 else {
            throw AdjustHoldingError.invalidQuantity
        }

        let movimiento = Movimiento.ajuste(
            fecha: input.fecha,
            cantidadCrypto: input.cantidad,
            cartera: input.cartera,
            crypto: input.crypto,
            motivo: input.motivo
        )

        try await transactionRunner.run { context in
            context.insert(movimiento)
            try holdingService.updateHoldingForMovement(movimiento, in: context)
            if let holding = try holding(for: movimiento, in: context) {
                holding.updatedAt = movimiento.fecha
            }
        }

        return movimiento
    }

    // MARK: - Private

    private func holding(for movimiento: Movimiento, in context: ModelContext) throws -> Holding? {
        guard let cartera = movimiento.cartera,
              let crypto = movimiento.crypto,
              let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else {
            return nil
        }
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }
}
