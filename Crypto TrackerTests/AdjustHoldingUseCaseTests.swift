import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `AdjustHoldingUseCase` manually sets a holding to an absolute quantity
/// and records a `.ajuste` movement atomically.
@MainActor
struct AdjustHoldingUseCaseTests {
    private func makeUseCase(context: ModelContext) -> AdjustHoldingUseCase {
        AdjustHoldingUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: HoldingService()
        )
    }

    private func makeContext() throws -> (ModelContext, Portfolio, Cartera, Crypto) {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(portfolio)
        context.insert(cartera)
        context.insert(btc)
        try context.save()
        return (context, portfolio, cartera, btc)
    }

    private func holding(
        in context: ModelContext,
        portfolio: Portfolio,
        cartera: Cartera,
        crypto: Crypto
    ) throws -> Holding? {
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    private func input(
        cantidad: Decimal,
        cartera: Cartera,
        crypto: Crypto,
        portfolio: Portfolio,
        fecha: Date = Date()
    ) -> AdjustHoldingInput {
        AdjustHoldingInput(
            fecha: fecha,
            portfolio: portfolio,
            cartera: cartera,
            crypto: crypto,
            cantidad: cantidad,
            motivo: nil
        )
    }

    @Test func adjustCreatesHoldingWhenMissing() async throws {
        let (context, portfolio, cartera, btc) = try makeContext()
        let useCase = makeUseCase(context: context)
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)

        let movimiento = try await useCase.execute(
            input(cantidad: 5, cartera: cartera, crypto: btc, portfolio: portfolio, fecha: fecha)
        )

        #expect(movimiento.tipo == .ajuste)
        #expect(movimiento.cantidadCrypto == 5)
        #expect(movimiento.valorTotalUSD == 250_000)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.updatedAt == fecha)
    }

    @Test func adjustOverwritesExistingHolding() async throws {
        let (context, portfolio, cartera, btc) = try makeContext()
        let useCase = makeUseCase(context: context)
        context.insert(Holding(portfolio: portfolio, cartera: cartera, crypto: btc, cantidad: 10))
        try context.save()

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 10)

        try await useCase.execute(input(cantidad: 3, cartera: cartera, crypto: btc, portfolio: portfolio))

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 3)
    }

    @Test func adjustToZeroDeletesHolding() async throws {
        let (context, portfolio, cartera, btc) = try makeContext()
        let useCase = makeUseCase(context: context)
        context.insert(Holding(portfolio: portfolio, cartera: cartera, crypto: btc, cantidad: 7))
        try context.save()

        try await useCase.execute(input(cantidad: 0, cartera: cartera, crypto: btc, portfolio: portfolio))

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
    }

    @Test func adjustNegativeQuantityThrows() async throws {
        let (context, portfolio, cartera, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        await #expect(throws: AdjustHoldingError.invalidQuantity) {
            try await useCase.execute(input(cantidad: -1, cartera: cartera, crypto: btc, portfolio: portfolio))
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    @Test func adjustIsAtomicWhenHoldingServiceFails() async throws {
        let (context, portfolio, cartera, btc) = try makeContext()
        let useCase = AdjustHoldingUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: ThrowingOnAdjustHoldingService()
        )

        do {
            _ = try await useCase.execute(input(cantidad: 5, cartera: cartera, crypto: btc, portfolio: portfolio))
            Issue.record("Expected adjust to throw")
        } catch is ThrowingOnAdjustHoldingService.Failure {
            // Expected: nothing persisted.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }
}

// MARK: - Fakes

private struct ThrowingOnAdjustHoldingService: HoldingServiceProtocol {
    struct Failure: Error {}

    func updateHoldingForMovement(_ movement: Movimiento, in context: ModelContext) throws {
        throw Failure()
    }

    func updateHoldingForMovement(_ movement: Movimiento, previous: HoldingSnapshot, in context: ModelContext) throws {
        throw Failure()
    }

    func deleteHoldingForMovement(_ movement: Movimiento, in context: ModelContext) throws {}

    func snapshot(of movement: Movimiento) -> HoldingSnapshot {
        HoldingSnapshot(movement: movement)
    }
}
