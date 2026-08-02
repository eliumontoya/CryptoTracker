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

    // MARK: - Salida editing

    @Test func editSalidaQuantityReducesExitAndHolding() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        // 5 BTC in, 2 BTC out → holding = 3.
        try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)

        try await useCase.execute(EditMovementInput(
            movement: salida,
            updated: values(cantidadCrypto: 1, precioUSD: 50_000, crypto: btc, cartera: wallet)
        ))

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 4)
        #expect(salida.cantidadCrypto == 1)
        #expect(salida.valorTotalUSD == 50_000)
    }

    @Test func editSalidaQuantityIncreasesExitWithinFunds() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        // 5 BTC in, 1 BTC out → holding = 4.
        try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 1, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 4)

        try await useCase.execute(EditMovementInput(
            movement: salida,
            updated: values(cantidadCrypto: 3, precioUSD: 50_000, crypto: btc, cartera: wallet)
        ))

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)
        #expect(salida.cantidadCrypto == 3)
    }

    @Test func editSalidaPriceDoesNotTouchHolding() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)

        try await useCase.execute(EditMovementInput(
            movement: salida,
            updated: values(cantidadCrypto: 2, precioUSD: 60_000, crypto: btc, cartera: wallet)
        ))

        #expect(salida.precioUSD == 60_000)
        #expect(salida.valorTotalUSD == 120_000)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)
    }

    @Test func editSalidaToSameValuesIsNoOp() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)

        try await useCase.execute(EditMovementInput(
            movement: salida,
            updated: values(
                cantidadCrypto: 2,
                precioUSD: 50_000,
                crypto: btc,
                cartera: wallet,
                fecha: salida.fecha
            )
        ))

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)
        #expect(salida.cantidadCrypto == 2)
        #expect(salida.precioUSD == 50_000)
    }

    @Test func editSalidaExceedingAvailableFundsThrows() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        // 5 BTC in, 2 BTC out → holding = 3.
        try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)

        // Editing exit 2 → 6: revert makes holding 5, but the new exit needs 6,
        // so it fails before mutation.
        await #expect(throws: EditMovementError.insufficientHoldings) {
            try await useCase.execute(EditMovementInput(
                movement: salida,
                updated: values(cantidadCrypto: 6, precioUSD: 50_000, crypto: btc, cartera: wallet)
            ))
        }

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)
        #expect(salida.cantidadCrypto == 2)
        #expect(salida.precioUSD == 50_000)
    }

    @Test func editSalidaToNewWalletWithInsufficientFundsThrows() async throws {
        let (context, portfolio, walletA, walletB, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        // Wallet A: 5 BTC in, 2 BTC out → holding A = 3.
        // Wallet B: no BTC holding.
        try await seedEntrada(in: context, cantidad: 5, wallet: walletA, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: walletA, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletA, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletB, crypto: btc) == nil)

        await #expect(throws: EditMovementError.insufficientHoldings) {
            try await useCase.execute(EditMovementInput(
                movement: salida,
                updated: values(cantidadCrypto: 1, precioUSD: 50_000, crypto: btc, cartera: walletB)
            ))
        }

        // Origin revert and destination application must both roll back.
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletA, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletB, crypto: btc) == nil)
        #expect(salida.cartera?.id == walletA.id)
    }

    @Test func editSalidaToNewWalletWithEnoughFundsApplies() async throws {
        let (context, portfolio, walletA, walletB, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        // Wallet A: 5 BTC in, 2 BTC out → holding A = 3.
        // Wallet B: 5 BTC in → holding B = 5.
        try await seedEntrada(in: context, cantidad: 5, wallet: walletA, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: walletA, crypto: btc)
        try await seedEntrada(in: context, cantidad: 5, wallet: walletB, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletA, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletB, crypto: btc)?.cantidad == 5)

        try await useCase.execute(EditMovementInput(
            movement: salida,
            updated: values(cantidadCrypto: 4, precioUSD: 50_000, crypto: btc, cartera: walletB)
        ))

        // A: reverted 2 → 5. B: 5 - 4 = 1.
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletA, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, wallet: walletB, crypto: btc)?.cantidad == 1)
        #expect(salida.cartera?.id == walletB.id)
        #expect(salida.cantidadCrypto == 4)
    }

    @Test func editSalidaToNewCryptoWithEnoughFundsApplies() async throws {
        let (context, portfolio, wallet, _, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)
        // BTC: 5 in, 2 out → holding BTC = 3.
        // ETH: 10 in → holding ETH = 10.
        try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        try await seedEntrada(in: context, cantidad: 10, wallet: wallet, crypto: eth)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: eth)?.cantidad == 10)

        try await useCase.execute(EditMovementInput(
            movement: salida,
            updated: values(cantidadCrypto: 4, precioUSD: 3_000, crypto: eth, cartera: wallet)
        ))

        // BTC: reverted 2 → 5. ETH: 10 - 4 = 6.
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: eth)?.cantidad == 6)
        #expect(salida.crypto?.id == eth.id)
        #expect(salida.cantidadCrypto == 4)
    }

    @Test func editSalidaToNewCryptoWithInsufficientFundsThrows() async throws {
        let (context, portfolio, wallet, _, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)
        try await seedEntrada(in: context, cantidad: 5, wallet: wallet, crypto: btc)
        let salida = try await seedSalida(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: eth) == nil)

        await #expect(throws: EditMovementError.insufficientHoldings) {
            try await useCase.execute(EditMovementInput(
                movement: salida,
                updated: values(cantidadCrypto: 1, precioUSD: 3_000, crypto: eth, cartera: wallet)
            ))
        }

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: eth) == nil)
        #expect(salida.crypto?.id == btc.id)
    }

    // MARK: - Unsupported movement type

    @Test func nonEntradaMovementThrowsUnsupportedType() async throws {
        let (context, _, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let ajuste = Movimiento(
            tipo: .ajuste,
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 50_000,
            valorTotalUSD: 50_000,
            cartera: wallet,
            crypto: btc
        )

        await #expect(throws: EditMovementError.unsupportedMovementType) {
            try await useCase.execute(EditMovementInput(
                movement: ajuste,
                updated: values(cantidadCrypto: 2, precioUSD: 50_000, crypto: btc, cartera: wallet)
            ))
        }
    }

    // MARK: - Edge cases

    @Test func editErrorDescriptionsAreLocalized() {
        #expect(EditMovementError.insufficientHoldings.errorDescription?.isEmpty == false)
        #expect(EditMovementError.unsupportedMovementType.errorDescription?.isEmpty == false)
    }

    @Test func editToSameValuesIsNoOp() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let entrada = try await seedEntrada(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)

        // Mismos valores que la entrada original → revertir y re-aplicar netea a cero.
        try await useCase.execute(EditMovementInput(
            movement: entrada,
            updated: values(
                cantidadCrypto: 2,
                precioUSD: 50_000,
                crypto: btc,
                cartera: wallet,
                fecha: entrada.fecha
            )
        ))

        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)
        #expect(entrada.cantidadCrypto == 2)
        #expect(entrada.precioUSD == 50_000)
        #expect(entrada.valorTotalUSD == 100_000)
    }

    @Test func editDetectsConcurrentModificationBeforeMutatingHolding() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let entrada = try await seedEntrada(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)

        // Modificación concurrente: otra parte mutó la entidad sin pasar por el
        // use case (holding desincronizado: 8 vs 2). El snapshot captura el estado
        // ya mutado y la validación de revert lo detecta: falla rápido.
        entrada.cantidadCrypto = 8

        await #expect(throws: EditMovementError.insufficientHoldings) {
            try await useCase.execute(EditMovementInput(
                movement: entrada,
                updated: values(cantidadCrypto: 5, precioUSD: 50_000, crypto: btc, cartera: wallet)
            ))
        }

        // El use case no tocó el holding ni aplicó su edición (validación previa).
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == 2)
        #expect(entrada.precioUSD == 50_000)
        #expect(entrada.valorTotalUSD == 100_000)
        // La mutación externa de la entidad es del caller, no del use case: queda
        // como el caller la dejó (fuera de la transacción del use case).
        #expect(entrada.cantidadCrypto == 8)
    }

    @Test func editWithLargeDecimalValuesUpdatesMovementAndHoldingExactly() async throws {
        let (context, portfolio, wallet, _, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let entrada = try await seedEntrada(in: context, cantidad: 2, wallet: wallet, crypto: btc)
        let largeQty: Decimal = 1_000_000_000_000
        let largePrice: Decimal = 1_000_000_000_000

        try await useCase.execute(EditMovementInput(
            movement: entrada,
            updated: values(cantidadCrypto: largeQty, precioUSD: largePrice, crypto: btc, cartera: wallet)
        ))

        #expect(entrada.cantidadCrypto == largeQty)
        #expect(entrada.precioUSD == largePrice)
        #expect(entrada.valorTotalUSD == largeQty * largePrice)
        #expect(try holding(in: context, portfolio: portfolio, wallet: wallet, crypto: btc)?.cantidad == largeQty)
    }

    @Test func editLegacyCarteraWithoutPortfolioSkipsHoldingValidation() async throws {
        // Cartera legacy sin portfolio y sin portfolio por defecto: no hay holding
        // materializado, la validación se salta y la edición persiste sin tocar holdings.
        let context = TestSetup.createModelContext()
        let legacy = Cartera(nombre: "Legacy Wallet", simbolo: "LEG")
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(legacy)
        context.insert(btc)
        try context.save()
        let useCase = makeUseCase(context: context)
        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: 2, precioUSD: 50_000, cartera: legacy, crypto: btc)
        context.insert(entrada)
        try context.save()

        try await useCase.execute(EditMovementInput(
            movement: entrada,
            updated: values(cantidadCrypto: 5, precioUSD: 50_000, crypto: btc, cartera: legacy)
        ))

        #expect(entrada.cantidadCrypto == 5)
        #expect(entrada.valorTotalUSD == 250_000)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }
}
