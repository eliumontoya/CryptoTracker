import Foundation
import SwiftData

// MARK: - Input

/// Values needed to perform a swap of crypto A for crypto B: a pair of movements
/// (`.swapSalida` of the origin crypto, `.swapEntrada` of the destination crypto)
/// sharing a `groupId`.
struct SwapMovementInput {
    let fecha: Date
    let cantidadOrigen: Decimal
    let cantidadDestino: Decimal
    let precioUSDOrigen: Decimal
    let precioUSDDestino: Decimal
    let cartera: Cartera
    let cryptoOrigen: Crypto
    let cryptoDestino: Crypto
}

// MARK: - Errors

/// Errors thrown by `SwapMovementUseCase`.
enum SwapMovementError: Error, LocalizedError, Equatable {
    /// Origin and destination cryptos must be different.
    case sameCrypto
    /// Origin wallet does not have enough of the origin crypto to cover the swap.
    case insufficientHoldings

    var errorDescription: String? {
        switch self {
        case .sameCrypto:
            return "Origin and destination cryptos must be different."
        case .insufficientHoldings:
            return "The wallet does not have enough of the origin crypto to cover this swap."
        }
    }
}

// MARK: - Result

/// The movement pair created by a successful swap.
struct SwapMovementResult {
    let salida: Movimiento
    let entrada: Movimiento
}

// MARK: - Protocol

/// Swaps crypto A for crypto B atomically: creates a pair of movements
/// (`.swapSalida` and `.swapEntrada`) that share a `groupId`, validates the origin
/// wallet holds enough of the origin crypto, and applies the signed holding deltas
/// inside a single `TransactionRunner` block.
@MainActor
protocol SwapMovementUseCaseProtocol {
    @discardableResult
    func execute(_ input: SwapMovementInput) async throws -> SwapMovementResult
}

// MARK: - Implementation

@MainActor
struct SwapMovementUseCase: SwapMovementUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    @discardableResult
    func execute(_ input: SwapMovementInput) async throws -> SwapMovementResult {
        guard input.cryptoOrigen.id != input.cryptoDestino.id else {
            throw SwapMovementError.sameCrypto
        }

        let par = Movimiento.swap(
            fecha: input.fecha,
            cantidadOrigen: input.cantidadOrigen,
            cantidadDestino: input.cantidadDestino,
            precioUSDOrigen: input.precioUSDOrigen,
            precioUSDDestino: input.precioUSDDestino,
            cartera: input.cartera,
            cryptoOrigen: input.cryptoOrigen,
            cryptoDestino: input.cryptoDestino
        )

        try await transactionRunner.run { context in
            try validateSufficientHoldings(for: par.salida, in: context)
            context.insert(par.salida)
            context.insert(par.entrada)
            try holdingService.updateHoldingForMovement(par.salida, in: context)
            try holdingService.updateHoldingForMovement(par.entrada, in: context)

            // Stamp the materialized holdings with the movement date, mirroring
            // the behaviour of `RegisterMovementUseCase`.
            if let originHolding = try holding(
                cartera: input.cartera,
                crypto: input.cryptoOrigen,
                in: context
            ) {
                originHolding.updatedAt = input.fecha
            }
            if let destinationHolding = try holding(
                cartera: input.cartera,
                crypto: input.cryptoDestino,
                in: context
            ) {
                destinationHolding.updatedAt = input.fecha
            }
        }

        return SwapMovementResult(salida: par.salida, entrada: par.entrada)
    }

    // MARK: - Private

    private func holding(cartera: Cartera, crypto: Crypto, in context: ModelContext) throws -> Holding? {
        guard let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else {
            return nil
        }
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    /// Fails fast when the origin wallet does not hold enough of the origin crypto.
    /// `Holding.cantidad` clamps at zero via `didSet`, so this guard runs BEFORE the
    /// subtraction so the domain error surfaces instead of silently erasing the row.
    private func validateSufficientHoldings(for movimiento: Movimiento, in context: ModelContext) throws {
        guard let cartera = movimiento.cartera,
              let crypto = movimiento.cryptoOrigen else {
            throw SwapMovementError.insufficientHoldings
        }
        guard let holding = try holding(cartera: cartera, crypto: crypto, in: context) else {
            // No holding row means zero available balance; any swap is invalid.
            throw SwapMovementError.insufficientHoldings
        }
        guard holding.cantidad >= movimiento.cantidadOrigen else {
            throw SwapMovementError.insufficientHoldings
        }
    }
}
