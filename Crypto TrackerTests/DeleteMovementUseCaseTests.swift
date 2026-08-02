import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `DeleteMovementUseCase` physically deletes an entry or exit movement
/// and reverts its holding in a single transaction, rejecting deletes that would
/// drive the materialized holding negative or that target unsupported movement types.
@MainActor
struct DeleteMovementUseCaseTests {
    private let holdingService = HoldingService()

    // MARK: - Helpers

    @discardableResult
    private func makeContext() throws -> (ModelContext, TransactionRunner, DeleteMovementUseCaseProtocol, Portfolio, Cartera, Crypto) {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(portfolio)
        context.insert(cartera)
        context.insert(btc)
        try context.save()
        let runner = ModelContextTransactionRunner(modelContext: context)
        let useCase = DeleteMovementUseCase(transactionRunner: runner, holdingService: holdingService)
        return (context, runner, useCase, portfolio, cartera, btc)
    }

    private func holding(in context: ModelContext, portfolio: Portfolio, cartera: Cartera, crypto: Crypto) throws -> Holding? {
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    /// Registers an entry movement and applies its holding effect (create path).
    @discardableResult
    private func registerEntrada(
        _ cantidad: Decimal,
        cartera: Cartera,
        crypto: Crypto,
        via runner: TransactionRunner
    ) async throws -> Movimiento {
        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: cantidad, precioUSD: 50_000, cartera: cartera, crypto: crypto)
        try await runner.run { ctx in
            ctx.insert(entrada)
            try self.holdingService.updateHoldingForMovement(entrada, in: ctx)
        }
        return entrada
    }

    /// Registers a sale movement and applies its holding effect.
    @discardableResult
    private func registerSalida(
        _ cantidad: Decimal,
        cartera: Cartera,
        crypto: Crypto,
        via runner: TransactionRunner
    ) async throws -> Movimiento {
        let salida = Movimiento.salida(fecha: Date(), cantidadCrypto: cantidad, precioUSD: 50_000, cartera: cartera, crypto: crypto)
        try await runner.run { ctx in
            ctx.insert(salida)
            try self.holdingService.updateHoldingForMovement(salida, in: ctx)
        }
        return salida
    }

    // MARK: - Delete simple entry

    @Test func deleteSimpleEntryRevertsHoldingToZeroAndRemovesMovement() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        let entrada = try await registerEntrada(4, cartera: cartera, crypto: btc, via: runner)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 4)

        try await useCase.delete(entrada)

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    // MARK: - Delete simple exit

    @Test func deleteSimpleExitRevertsHoldingAndRemovesMovement() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        try await registerEntrada(4, cartera: cartera, crypto: btc, via: runner)
        let salida = try await registerSalida(4, cartera: cartera, crypto: btc, via: runner)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)

        try await useCase.delete(salida)

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 4)
    }

    @Test func deleteExitWhenHoldingPartiallySpentAddsBackQuantity() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        try await registerEntrada(4, cartera: cartera, crypto: btc, via: runner)
        let salida = try await registerSalida(2, cartera: cartera, crypto: btc, via: runner)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)

        try await useCase.delete(salida)

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 4)
    }

    // MARK: - Delete when holding partially spent

    @Test func deleteEntryWhenHoldingPartiallySpentKeepsPositiveBalance() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        // Entradas 6 + 4 → holding 10; venta 4 → holding 6 (parcialmente gastado).
        let primera = try await registerEntrada(6, cartera: cartera, crypto: btc, via: runner)
        let segunda = try await registerEntrada(4, cartera: cartera, crypto: btc, via: runner)
        try await registerSalida(4, cartera: cartera, crypto: btc, via: runner)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 6)

        // Eliminar la segunda entrada (4): 6 - 4 = 2 ≥ 0 → permitido.
        try await useCase.delete(segunda)

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
        // Quedan la primera entrada y la venta.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 2)
        #expect(primera.id != segunda.id)
    }

    // MARK: - Delete that would make holding negative

    @Test func deleteThatWouldMakeHoldingNegativeIsRejectedAtomically() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        // Entradas 6 + 4 → holding 10; venta 7 → holding 3.
        let primera = try await registerEntrada(6, cartera: cartera, crypto: btc, via: runner)
        try await registerEntrada(4, cartera: cartera, crypto: btc, via: runner)
        try await registerSalida(7, cartera: cartera, crypto: btc, via: runner)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 3)

        // Eliminar la primera (6): 3 - 6 < 0 → error, nada se persiste.
        await #expect(throws: DeleteMovementError.insufficientHoldings) {
            try await useCase.delete(primera)
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 3)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 3)
    }

    // MARK: - Scope: entrada and salida only

    @Test func deleteNonEntryOrExitMovementIsRejected() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        try await registerEntrada(5, cartera: cartera, crypto: btc, via: runner)
        let ajuste = Movimiento(
            tipo: .ajuste,
            fecha: Date(),
            cantidadCrypto: 1,
            precioUSD: 50_000,
            valorTotalUSD: 50_000,
            cartera: cartera,
            crypto: btc
        )
        try await runner.run { ctx in
            ctx.insert(ajuste)
        }

        await #expect(throws: DeleteMovementError.unsupportedMovementType(.ajuste)) {
            try await useCase.delete(ajuste)
        }

        // Nothing changed: the ajuste and the entry still exist, holding stays intact.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 2)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 5)
    }

    // MARK: - Edge cases

    @Test func deleteErrorDescriptionsAreLocalized() {
        #expect(DeleteMovementError.unsupportedMovementType(.ajuste).errorDescription?.isEmpty == false)
        #expect(DeleteMovementError.insufficientHoldings.errorDescription?.isEmpty == false)
        #expect(DeleteMovementError.missingPairedMovement.errorDescription?.isEmpty == false)
    }

    @Test func deleteAlreadyDeletedMovementThrowsAndKeepsStoreConsistent() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        let entrada = try await registerEntrada(4, cartera: cartera, crypto: btc, via: runner)

        try await useCase.delete(entrada)
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)

        // Segundo delete sobre la misma instancia: el holding ya no cubre la
        // cantidad → falla rápido sin tocar nada más.
        await #expect(throws: DeleteMovementError.insufficientHoldings) {
            try await useCase.delete(entrada)
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    @Test func deleteWithZeroHoldingIsRejected() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        // Entrada 5 + salida 5 → el holding se elimina al llegar a cero.
        let entrada = try await registerEntrada(5, cartera: cartera, crypto: btc, via: runner)
        try await registerSalida(5, cartera: cartera, crypto: btc, via: runner)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)

        // Revertir la entrada (5) sobre un holding inexistente (0) → negativo.
        await #expect(throws: DeleteMovementError.insufficientHoldings) {
            try await useCase.delete(entrada)
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 2)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    @Test func deleteAndReRegisterRebuildsHolding() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        let register = RegisterMovementUseCase(transactionRunner: runner, holdingService: holdingService)
        let input = RegisterMovementInput(
            fecha: Date(),
            cantidadCrypto: 4,
            precioUSD: 50_000,
            usaFiatAlterno: false,
            precioFiatAlterno: nil,
            valorTotalFiatAlterno: nil,
            cartera: cartera,
            crypto: btc,
            fiatAlterno: nil
        )

        // Registro → delete → re-registro: el ciclo completo queda consistente.
        let primero = try await register.register(input)
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 4)

        try await useCase.delete(primero)
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)

        try await register.register(input)
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 4)
    }

    @Test func deleteLegacyCarteraWithoutPortfolioDeletesMovementWithoutHolding() async throws {
        // Cartera legacy sin portfolio y sin portfolio por defecto: no hay holding
        // materializado, la validación se salta y el delete persiste sin tocar holdings.
        let context = TestSetup.createModelContext()
        let legacy = Cartera(nombre: "Legacy Wallet", simbolo: "LEG")
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(legacy)
        context.insert(btc)
        try context.save()
        let runner = ModelContextTransactionRunner(modelContext: context)
        let useCase = DeleteMovementUseCase(transactionRunner: runner, holdingService: holdingService)
        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: 2, precioUSD: 50_000, cartera: legacy, crypto: btc)
        context.insert(entrada)
        try context.save()

        try await useCase.delete(entrada)

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    // MARK: - Transfer delete

    @Test func deleteTransferRemovesBothLegsAndRevertsHoldings() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        let destination = Cartera(nombre: "Destination Wallet", simbolo: "DEST", portfolio: portfolio)
        context.insert(destination)
        try context.save()

        try await registerEntrada(5, cartera: cartera, crypto: btc, via: runner)
        let transferUseCase = MoveBetweenWalletsUseCase(transactionRunner: runner, holdingService: holdingService)
        let transfer = try await transferUseCase.execute(
            MoveBetweenWalletsInput(
                fecha: Date(),
                cantidadCryptoSalida: 3,
                cantidadCryptoEntrada: 2,
                precioUSD: 50_000,
                carteraOrigen: cartera,
                carteraDestino: destination,
                crypto: btc
            )
        )
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.cantidad == 2)

        try await useCase.delete(transfer.salida)

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1) // seeded entry only
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc) == nil)
    }

    @Test func deleteTransferFromEntradaLegRemovesBothLegs() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        let destination = Cartera(nombre: "Destination Wallet", simbolo: "DEST", portfolio: portfolio)
        context.insert(destination)
        try context.save()

        try await registerEntrada(5, cartera: cartera, crypto: btc, via: runner)
        let transferUseCase = MoveBetweenWalletsUseCase(transactionRunner: runner, holdingService: holdingService)
        let transfer = try await transferUseCase.execute(
            MoveBetweenWalletsInput(
                fecha: Date(),
                cantidadCryptoSalida: 3,
                cantidadCryptoEntrada: 2,
                precioUSD: 50_000,
                carteraOrigen: cartera,
                carteraDestino: destination,
                crypto: btc
            )
        )

        try await useCase.delete(transfer.entrada)

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc) == nil)
    }

    @Test func deleteTransferRejectionWhenDestinationSpentTooMuch() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        let destination = Cartera(nombre: "Destination Wallet", simbolo: "DEST", portfolio: portfolio)
        context.insert(destination)
        try context.save()

        try await registerEntrada(5, cartera: cartera, crypto: btc, via: runner)
        let transferUseCase = MoveBetweenWalletsUseCase(transactionRunner: runner, holdingService: holdingService)
        let transfer = try await transferUseCase.execute(
            MoveBetweenWalletsInput(
                fecha: Date(),
                cantidadCryptoSalida: 3,
                cantidadCryptoEntrada: 3,
                precioUSD: 50_000,
                carteraOrigen: cartera,
                carteraDestino: destination,
                crypto: btc
            )
        )
        // Destination receives 3, then sells 2. Destination now has 1.
        let salidaDesdeDestino = Movimiento.salida(
            fecha: Date(),
            cantidadCrypto: 2,
            precioUSD: 50_000,
            cartera: destination,
            crypto: btc
        )
        try await runner.run { ctx in
            ctx.insert(salidaDesdeDestino)
            try holdingService.updateHoldingForMovement(salidaDesdeDestino, in: ctx)
        }
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.cantidad == 1)

        // Reverting the transfer entrada (-3) would leave destination at -2.
        await #expect(throws: DeleteMovementError.insufficientHoldings) {
            try await useCase.delete(transfer.salida)
        }

        // All 4 movements remain: seeded entry, transfer pair, and destination sale.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 4)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.cantidad == 1)
    }
}
