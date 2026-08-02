import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `DeleteMovementUseCase` physically deletes an entry movement and
/// reverts its holding in a single transaction, rejecting deletes that would
/// drive the materialized holding negative or that target non-entry movements.
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

    // MARK: - Scope: entrada only

    @Test func deleteNonEntryMovementIsRejected() async throws {
        let (context, runner, useCase, portfolio, cartera, btc) = try makeContext()
        try await registerEntrada(5, cartera: cartera, crypto: btc, via: runner)
        let salida = try await registerSalida(2, cartera: cartera, crypto: btc, via: runner)

        await #expect(throws: DeleteMovementError.unsupportedMovementType(.salida)) {
            try await useCase.delete(salida)
        }

        // Nada cambió: la salida sigue existiendo y el holding quedó intacto.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 2)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 3)
    }
}
