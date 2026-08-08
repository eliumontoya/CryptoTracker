import Foundation
import SwiftData

// MARK: - Input

/// Values needed to register an entry or exit movement (`tipo = .entrada` or `.salida`).
/// `valorTotalUSD` is derived as `cantidadCrypto * precioUSD`; when the movement is
/// paid in an alternate FIAT, `precioUSD` already reflects the FIAT → USD conversion
/// and the alternate fields are persisted alongside.
struct RegisterMovementInput {
    let fecha: Date
    let cantidadCrypto: Decimal
    let precioUSD: Decimal
    let usaFiatAlterno: Bool
    let precioFiatAlterno: Decimal?
    let valorTotalFiatAlterno: Decimal?
    let cartera: Cartera
    let crypto: Crypto
    let fiatAlterno: FIAT?
}

// MARK: - Errors

/// Errors thrown by `RegisterMovementUseCase`.
enum RegisterMovementError: Error, LocalizedError, Equatable {
    /// The wallet does not hold enough crypto to cover the requested exit quantity.
    case insufficientHoldings

    var errorDescription: String? {
        switch self {
        case .insufficientHoldings:
            return "La cartera no tiene suficiente saldo para realizar la salida."
        }
    }
}

// MARK: - Protocol

/// Registers an entry or exit movement and its holding effect atomically: the `Movimiento`
/// insert and the materialized `Holding` update persist (or roll back) together
/// inside a single `TransactionRunner` block.
@MainActor
protocol RegisterMovementUseCaseProtocol {
    @discardableResult
    func register(_ input: RegisterMovementInput) async throws -> Movimiento

    @discardableResult
    func registerSalida(_ input: RegisterMovementInput) async throws -> Movimiento
}

// MARK: - Implementation

/// Domain use case for entries (`.entrada`) and exits (`.salida`): builds the movement,
/// inserts it, applies the signed holding delta, and stamps `holding.updatedAt` with the
/// movement's `fecha`. Never calls `save()` directly — the injected `TransactionRunner`
/// owns persistence.
@MainActor
struct RegisterMovementUseCase: RegisterMovementUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    @discardableResult
    func register(_ input: RegisterMovementInput) async throws -> Movimiento {
        let movimiento = Movimiento.entrada(
            fecha: input.fecha,
            cantidadCrypto: input.cantidadCrypto,
            precioUSD: input.precioUSD,
            usaFiatAlterno: input.usaFiatAlterno,
            precioFiatAlterno: input.precioFiatAlterno,
            valorTotalFiatAlterno: input.valorTotalFiatAlterno,
            cartera: input.cartera,
            crypto: input.crypto,
            fiatAlterno: input.fiatAlterno
        )

        try await transactionRunner.run { context in
            context.insert(movimiento)
            try holdingService.updateHoldingForMovement(movimiento, in: context)
            if let holding = try fetchHolding(for: movimiento, in: context) {
                holding.updatedAt = movimiento.fecha
            }
        }

        return movimiento
    }

    @discardableResult
    func registerSalida(_ input: RegisterMovementInput) async throws -> Movimiento {
        let movimiento = Movimiento.salida(
            fecha: input.fecha,
            cantidadCrypto: input.cantidadCrypto,
            precioUSD: input.precioUSD,
            usaFiatAlterno: input.usaFiatAlterno,
            precioFiatAlterno: input.precioFiatAlterno,
            valorTotalFiatAlterno: input.valorTotalFiatAlterno,
            cartera: input.cartera,
            crypto: input.crypto,
            fiatAlterno: input.fiatAlterno
        )

        try await transactionRunner.run { context in
            try validateSufficientHoldings(for: movimiento, in: context)
            context.insert(movimiento)
            try holdingService.updateHoldingForMovement(movimiento, in: context)
            if let holding = try fetchHolding(for: movimiento, in: context) {
                holding.updatedAt = movimiento.fecha
            }
        }

        return movimiento
    }

    // MARK: - Private

    /// Resolves the holding row affected by the movement using the same key resolution as
    /// `HoldingService` (cartera.portfolio, falling back to the default portfolio).
    private func fetchHolding(for movimiento: Movimiento, in context: ModelContext) throws -> Holding? {
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

    /// Fails fast when an exit would drive the wallet's holding below zero.
    ///
    /// `Holding.cantidad` clamps at zero via `didSet`, so this guard runs BEFORE the
    /// subtraction so the domain error surfaces instead of silently erasing the row.
    private func validateSufficientHoldings(for movimiento: Movimiento, in context: ModelContext) throws {
        guard let holding = try fetchHolding(for: movimiento, in: context) else {
            // No holding row means zero available balance; any exit is invalid.
            throw RegisterMovementError.insufficientHoldings
        }
        guard holding.cantidad >= movimiento.cantidadCrypto else {
            throw RegisterMovementError.insufficientHoldings
        }
    }
}
