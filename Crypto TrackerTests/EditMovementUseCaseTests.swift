import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `EditMovementUseCase` reverts the old holding effect and applies the
/// new one atomically when an entry movement is edited, including wallet/crypto
/// changes and the negative-balance guard.
@MainActor
struct EditMovementUseCaseTests {
    // MARK: - Helpers

    private func makeContext() throws -> (ModelContext, Portfolio, Cartera, Cartera, Crypto, Crypto) {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let walletA = Cartera(nombre: "Wallet A", simbolo: "WA", portfolio: portfolio)
        let walletB = Cartera(nombre: "Wallet B", simbolo: "WB", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        let eth = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3_000)
        context.insert(portfolio)
        context.insert(walletA)
        context.insert(walletB)
        context.insert(btc)
        context.insert(eth)
        try context.save()
        return (context, portfolio, walletA, walletB, btc, eth)
    }

    private func makeUseCase(context: ModelContext) -> EditMovementUseCase {
        EditMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: HoldingService()
        )
    }

    @discardableResult
    private func seedEntrada(
        in context: ModelContext,
        cantidad: Decimal,
        wallet: Cartera,
        crypto: Crypto
    ) async throws -> Movimiento {
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: cantidad, precioUSD: 50_000, cartera: wallet, crypto: crypto)
        let runner = ModelContextTransactionRunner(modelContext: context)
        try await runner.run { ctx in
            ctx.insert(movimiento)
            try HoldingService().updateHoldingForMovement(movimiento, in: ctx)
        }
        return movimiento
    }

    @discardableResult
    private func seedSalida(
        in context: ModelContext,
        cantidad: Decimal,
        wallet: Cartera,
        crypto: Crypto
    ) async throws -> Movimiento {
        let movimiento = Movimiento.salida(fecha: Date(), cantidadCrypto: cantidad, precioUSD: 50_000, cartera: wallet, crypto: crypto)
        let runner = ModelContextTransactionRunner(modelContext: context)
        try await runner.run { ctx in
            ctx.insert(movimiento)
            try HoldingService().updateHoldingForMovement(movimiento, in: ctx)
        }
        return movimiento
    }

    private func holding(in context: ModelContext, portfolio: Portfolio, wallet: Cartera, crypto: Crypto) throws -> Holding? {
        let key = Holding.makeId(portfolio: portfolio, cartera: wallet, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    private func values(
        cantidadCrypto: Decimal,
        precioUSD: Decimal,
        crypto: Crypto,
        cartera: Cartera,
        fecha: Date = Date()
    ) -> EditMovementValues {
        EditMovementValues(
            fecha: fecha,
            cantidadCrypto: cantidadCrypto,
            precioUSD: precioUSD,
            valorTotalUSD: cantidadCrypto * precioUSD,
            usaFiatAlterno: false,
            precioFiatAlterno: nil,
            valorTotalFiatAlterno: nil,
            crypto: crypto,
            cartera: cartera,
            fiatAlterno: nil
        )
    }

    // MARK: - Edit quantity

    @Test func editQuantityAdjustsHoldingAndMovement() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let entrada = try await seedEntrada(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)

        try await useCase.execute(EditMovementInput(
            movement: entrada,
            updated: values(cantidadCrypto: 5, precioUSD: 50_000, crypto: btc, cartera: wallet)
        ))

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 5)
        #expect(entrada.cantidadCrypto == 5)
        #expect(entrada.valorTotalUSD == 250_000)
    }

    // MARK: - Edit price

    @Test func editPriceUpdatesMovementWithoutTouchingHolding() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let entrada = try await seedEntrada(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)

        try await useCase.execute(EditMovementInput(
            movement: entrada,
            updated: values(cantidadCrypto: 2, precioUSD: 60_000, crypto: btc, cartera: wallet)
        ))

        #expect(entrada.precioUSD == 60_000)
        #expect(entrada.valorTotalUSD == 120_000)
        // Quantity unchanged → holding unchanged.
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)
    }

    // MARK: - Change wallet

    @Test func changeWalletMovesHoldingToNewWallet() async throws {
        let (context, portfolio, walletA, walletB, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let entrada = try await seedEntrada(in: context, cantidad: 2, wallet: walletA, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletA, crypto: btc)?.cantidad == 2)

        try await useCase.execute(EditMovementInput(
            movement: entrada,
            updated: values(cantidadCrypto: 2, precioUSD: 50_000, crypto: btc, cartera: walletB)
        ))

        // Old wallet holding fully reverted (row deleted at zero).
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletA, crypto: btc) == nil)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletB, crypto: btc)?.cantidad == 2)
        #expect(entrada.cartera?.id == walletB.id)
    }

    // MARK: - Change crypto

    @Test func changeCryptoMovesHoldingToNewCrypto() async throws {
        let (context, portfolio, wallet, _, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)
        let entrada = try await seedEntrada(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)

        try await useCase.execute(EditMovementInput(
            movement: entrada,
            updated: values(cantidadCrypto: 2, precioUSD: 3_000, crypto: eth, cartera: wallet)
        ))

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc) == nil)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: eth)?.cantidad == 2)
        #expect(entrada.crypto?.id == eth.id)
    }

    // MARK: - Negative balance guard

    @Test func revertBelowZeroThrowsAndPersistsNothing() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        // 5 BTC in, 3 BTC out → holding = 2.
        let entrada = try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        try await seedSalida(in: context, cantidad: 3, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)

        // Editing 5 → 8 would revert 2 - 5 = -3: must fail before any mutation.
        await #expect(throws: EditMovementError.insufficientHoldings) {
            try await useCase.execute(EditMovementInput(
                movement: entrada,
                updated: values(cantidadCrypto: 8, precioUSD: 50_000, crypto: btc, cartera: wallet)
            ))
        }

        // Atomicity: nothing persisted, movement unchanged.
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)
        #expect(entrada.cantidadCrypto == 5)
        #expect(entrada.precioUSD == 50_000)
    }

    // MARK: - Unsupported movement type

    @Test func nonEntradaMovementThrowsUnsupportedType() async throws {
        let (context, _, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let salida = Movimiento.salida(fecha: Date(), cantidadCrypto: 1, precioUSD: 50_000, cartera: wallet, crypto: btc)

        await #expect(throws: EditMovementError.unsupportedMovementType) {
            try await useCase.execute(EditMovementInput(
                movement: salida,
                updated: values(cantidadCrypto: 2, precioUSD: 50_000, crypto: btc, cartera: wallet)
            ))
        }
    }
}
