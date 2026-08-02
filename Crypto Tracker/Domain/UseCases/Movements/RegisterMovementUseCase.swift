import Foundation
import SwiftData

// MARK: - Input

/// Values needed to register an entry movement (`tipo = .entrada`).
/// `valorTotalUSD` is derived as `cantidadCrypto * precioUSD`; when the entry is
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

// MARK: - Protocol

/// Registers an entry movement and its holding effect atomically: the `Movimiento`
/// insert and the materialized `Holding` update persist (or roll back) together
/// inside a single `TransactionRunner` block.
protocol RegisterMovementUseCaseProtocol {
    @discardableResult
    func register(_ input: RegisterMovementInput) async throws -> Movimiento
}

// MARK: - Implementation

/// Domain use case for entries (`.entrada`): builds `Movimiento.entrada`, inserts it,
/// applies the `+cantidadCrypto` holding delta, and stamps `holding.updatedAt` with the
/// movement's `fecha`. Never calls `save()` directly — the injected `TransactionRunner`
/// owns persistence.
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

    // MARK: - Private

    /// Resolves the holding row affected by the entry using the same key resolution as
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
}
