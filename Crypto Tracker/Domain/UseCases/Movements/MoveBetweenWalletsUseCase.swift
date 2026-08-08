import Foundation
import SwiftData

// MARK: - Input

/// Values needed to transfer crypto between wallets: a pair of movements
/// (`.transferenciaSalida` from origin, `.transferenciaEntrada` to destination)
/// sharing a `groupId`. The commission is the difference between the sent and
/// received amounts.
struct MoveBetweenWalletsInput {
    let fecha: Date
    let cantidadCryptoSalida: Decimal
    let cantidadCryptoEntrada: Decimal
    let precioUSD: Decimal
    let carteraOrigen: Cartera
    let carteraDestino: Cartera
    let crypto: Crypto

    var commission: Decimal {
        cantidadCryptoSalida - cantidadCryptoEntrada
    }
}

// MARK: - Errors

/// Errors thrown by `MoveBetweenWalletsUseCase`.
enum MoveBetweenWalletsError: Error, LocalizedError, Equatable {
    /// Origin and destination wallets must be different.
    case sameWallet
    /// The destination amount cannot exceed the origin amount.
    case negativeCommission
    /// Origin wallet does not have enough funds to cover the transfer.
    case insufficientHoldings

    var errorDescription: String? {
        switch self {
        case .sameWallet:
            return "Origin and destination wallets must be different."
        case .negativeCommission:
            return "The received amount cannot exceed the sent amount."
        case .insufficientHoldings:
            return "The origin wallet does not have enough funds for this transfer."
        }
    }
}

// MARK: - Result

/// The movement pair created by a successful transfer.
struct MoveBetweenWalletsResult {
    let salida: Movimiento
    let entrada: Movimiento
}

// MARK: - Protocol

/// Transfers crypto between two wallets atomically: creates a pair of movements
/// (`.transferenciaSalida` and `.transferenciaEntrada`) that share a `groupId`,
/// validates the origin wallet has enough funds, and applies the signed holding
/// deltas inside a single `TransactionRunner` block.
@MainActor
protocol MoveBetweenWalletsUseCaseProtocol {
    @discardableResult
    func execute(_ input: MoveBetweenWalletsInput) async throws -> MoveBetweenWalletsResult
}

// MARK: - Implementation

@MainActor
struct MoveBetweenWalletsUseCase: MoveBetweenWalletsUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    @discardableResult
    func execute(_ input: MoveBetweenWalletsInput) async throws -> MoveBetweenWalletsResult {
        guard input.carteraOrigen.id != input.carteraDestino.id else {
            throw MoveBetweenWalletsError.sameWallet
        }
        guard input.cantidadCryptoEntrada <= input.cantidadCryptoSalida else {
            throw MoveBetweenWalletsError.negativeCommission
        }

        let par = Movimiento.transferencia(
            fecha: input.fecha,
            cantidadCryptoSalida: input.cantidadCryptoSalida,
            cantidadCryptoEntrada: input.cantidadCryptoEntrada,
            carteraOrigen: input.carteraOrigen,
            carteraDestino: input.carteraDestino,
            crypto: input.crypto
        )

        // Transfers still carry the common USD fields so the movement can be
        // valued independently of the holding delta.
        par.salida.precioUSD = input.precioUSD
        par.salida.valorTotalUSD = input.cantidadCryptoSalida * input.precioUSD
        par.entrada.precioUSD = input.precioUSD
        par.entrada.valorTotalUSD = input.cantidadCryptoEntrada * input.precioUSD

        try await transactionRunner.run { context in
            try validateSufficientHoldings(for: par.salida, in: context)
            context.insert(par.salida)
            context.insert(par.entrada)
            try holdingService.updateHoldingForMovement(par.salida, in: context)
            try holdingService.updateHoldingForMovement(par.entrada, in: context)

            // Stamp the materialized holdings with the movement date, mirroring
            // the behaviour of `RegisterMovementUseCase`.
            if let originHolding = try holding(
                cartera: input.carteraOrigen,
                crypto: input.crypto,
                in: context
            ) {
                originHolding.updatedAt = input.fecha
            }
            if let destinationHolding = try holding(
                cartera: input.carteraDestino,
                crypto: input.crypto,
                in: context
            ) {
                destinationHolding.updatedAt = input.fecha
            }
        }

        return MoveBetweenWalletsResult(salida: par.salida, entrada: par.entrada)
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

    /// Fails fast when the origin wallet does not hold enough crypto to cover the
    /// outgoing transfer leg. `Holding.cantidad` clamps at zero via `didSet`, so
    /// this guard runs BEFORE the subtraction so the domain error surfaces instead
    /// of silently erasing the row.
    private func validateSufficientHoldings(for movimiento: Movimiento, in context: ModelContext) throws {
        guard let carteraOrigen = movimiento.carteraOrigen,
              let crypto = movimiento.crypto else {
            // A transfer leg without origin or crypto references cannot be validated.
            throw MoveBetweenWalletsError.insufficientHoldings
        }
        guard let holding = try holding(cartera: carteraOrigen, crypto: crypto, in: context) else {
            // No holding row means zero available balance; any transfer is invalid.
            throw MoveBetweenWalletsError.insufficientHoldings
        }
        guard holding.cantidad >= movimiento.cantidadCryptoSalida else {
            throw MoveBetweenWalletsError.insufficientHoldings
        }
    }
}
