import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `SwapMovementUseCase` creates a pair of swap movements
/// (`.swapSalida` + `.swapEntrada`) atomically, validates the origin wallet has
/// enough of the origin crypto, updates materialized holdings, and rolls back on failure.
@MainActor
struct SwapMovementUseCaseTests {
    private func makeUseCase(context: ModelContext) -> SwapMovementUseCase {
        SwapMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: HoldingService()
        )
    }

    @discardableResult
    private func makeContext() throws -> (ModelContext, Portfolio, Cartera, Crypto, Crypto) {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let wallet = Cartera(nombre: "Test Wallet", simbolo: "TST", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        let eth = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3_000)
        context.insert(portfolio)
        context.insert(wallet)
        context.insert(btc)
        context.insert(eth)
        try context.save()
        return (context, portfolio, wallet, btc, eth)
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
        fecha: Date = Date(),
        cantidadOrigen: Decimal = 1,
        cantidadDestino: Decimal = 10,
        precioUSDOrigen: Decimal = 50_000,
        precioUSDDestino: Decimal = 3_000,
        cartera: Cartera,
        cryptoOrigen: Crypto,
        cryptoDestino: Crypto
    ) -> SwapMovementInput {
        SwapMovementInput(
            fecha: fecha,
            cantidadOrigen: cantidadOrigen,
            cantidadDestino: cantidadDestino,
            precioUSDOrigen: precioUSDOrigen,
            precioUSDDestino: precioUSDDestino,
            cartera: cartera,
            cryptoOrigen: cryptoOrigen,
            cryptoDestino: cryptoDestino
        )
    }

    private func seedHolding(
        in context: ModelContext,
        portfolio: Portfolio,
        cartera: Cartera,
        crypto: Crypto,
        cantidad: Decimal
    ) async throws {
        let entrada = Movimiento.entrada(
            fecha: Date(),
            cantidadCrypto: cantidad,
            precioUSD: 50_000,
            cartera: cartera,
            crypto: crypto
        )
        try await ModelContextTransactionRunner(modelContext: context).run { ctx in
            ctx.insert(entrada)
            try HoldingService().updateHoldingForMovement(entrada, in: ctx)
        }
    }

    // MARK: - Happy path

    @Test func swapCreatesMovementPairWithSharedGroupId() async throws {
        let (context, _, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)

        try await seedHolding(in: context, portfolio: PortfolioQueries.defaultPortfolio(in: context)!, cartera: wallet, crypto: btc, cantidad: 5)

        let result = try await useCase.execute(
            input(
                fecha: fecha,
                cantidadOrigen: 1,
                cantidadDestino: 10,
                precioUSDOrigen: 50_000,
                precioUSDDestino: 3_000,
                cartera: wallet,
                cryptoOrigen: btc,
                cryptoDestino: eth
            )
        )

        let movements = try context.fetch(FetchDescriptor<Movimiento>(sortBy: [SortDescriptor(\.tipoRaw)]))
        #expect(movements.count == 3) // seeded entry + swap pair

        #expect(result.salida.tipo == .swapSalida)
        #expect(result.entrada.tipo == .swapEntrada)
        #expect(result.salida.groupId == result.entrada.groupId)
        #expect(result.salida.groupId != nil)

        #expect(result.salida.cantidadOrigen == 1)
        #expect(result.salida.cantidadDestino == 10)
        #expect(result.entrada.cantidadOrigen == 1)
        #expect(result.entrada.cantidadDestino == 10)

        #expect(result.salida.cartera?.id == wallet.id)
        #expect(result.entrada.cartera?.id == wallet.id)
        #expect(result.salida.cryptoOrigen?.id == btc.id)
        #expect(result.salida.cryptoDestino?.id == eth.id)
        #expect(result.entrada.cryptoOrigen?.id == btc.id)
        #expect(result.entrada.cryptoDestino?.id == eth.id)

        #expect(result.salida.precioUSDOrigen == 50_000)
        #expect(result.salida.precioUSDDestino == 3_000)
        #expect(result.entrada.precioUSDOrigen == 50_000)
        #expect(result.entrada.precioUSDDestino == 3_000)

        #expect(result.salida.fecha == fecha)
        #expect(result.entrada.fecha == fecha)
    }

    @Test func swapMovesHoldingsBetweenCryptos() async throws {
        let (context, portfolio, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc, cantidad: 10)

        _ = try await useCase.execute(
            input(
                cantidadOrigen: 2,
                cantidadDestino: 20,
                cartera: wallet,
                cryptoOrigen: btc,
                cryptoDestino: eth
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc)?.cantidad == 8)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth)?.cantidad == 20)
    }

    @Test func swapStampsHoldingsUpdatedAtWithMovementDate() async throws {
        let (context, portfolio, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)

        try await seedHolding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc, cantidad: 5)

        _ = try await useCase.execute(
            input(
                fecha: fecha,
                cantidadOrigen: 2,
                cantidadDestino: 20,
                cartera: wallet,
                cryptoOrigen: btc,
                cryptoDestino: eth
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc)?.updatedAt == fecha)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth)?.updatedAt == fecha)
    }

    @Test func swapDestinationHoldingCreatedWhenMissing() async throws {
        let (context, portfolio, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc, cantidad: 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth) == nil)

        _ = try await useCase.execute(
            input(
                cantidadOrigen: 1,
                cantidadDestino: 10,
                cartera: wallet,
                cryptoOrigen: btc,
                cryptoDestino: eth
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth)?.cantidad == 10)
    }

    @Test func swapOriginHoldingDeletedAtZero() async throws {
        let (context, portfolio, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc, cantidad: 2)

        _ = try await useCase.execute(
            input(
                cantidadOrigen: 2,
                cantidadDestino: 20,
                cartera: wallet,
                cryptoOrigen: btc,
                cryptoDestino: eth
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc) == nil)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth)?.cantidad == 20)
    }

    // MARK: - Validation errors

    @Test func swapSameCryptoThrowsSameCryptoError() async throws {
        let (context, _, wallet, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)

        await #expect(throws: SwapMovementError.sameCrypto) {
            _ = try await useCase.execute(
                input(cartera: wallet, cryptoOrigen: btc, cryptoDestino: btc)
            )
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    @Test func swapWithMissingOriginHoldingThrowsInsufficientHoldings() async throws {
        let (context, _, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)

        await #expect(throws: SwapMovementError.insufficientHoldings) {
            _ = try await useCase.execute(
                input(cartera: wallet, cryptoOrigen: btc, cryptoDestino: eth)
            )
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    @Test func swapWithInsufficientOriginFundsThrowsAndLeavesStoreUnchanged() async throws {
        let (context, portfolio, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc, cantidad: 1)

        await #expect(throws: SwapMovementError.insufficientHoldings) {
            _ = try await useCase.execute(
                input(
                    cantidadOrigen: 2,
                    cantidadDestino: 20,
                    cartera: wallet,
                    cryptoOrigen: btc,
                    cryptoDestino: eth
                )
            )
        }

        // Only the seeded entry exists, and the origin holding is untouched.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc)?.cantidad == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth) == nil)
    }

    // MARK: - Atomicity

    @Test func swapRollsBackBothMovementsWhenHoldingUpdateFails() async throws {
        let (context, portfolio, wallet, btc, eth) = try makeContext()
        let useCase = SwapMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: ThrowingOnSwapHoldingService()
        )

        try await seedHolding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc, cantidad: 5)

        do {
            _ = try await useCase.execute(
                input(cartera: wallet, cryptoOrigen: btc, cryptoDestino: eth)
            )
            Issue.record("Expected execute to throw")
        } catch is ThrowingOnSwapHoldingService.Failure {
            // Expected: both inserts are rolled back.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1) // seeded entry only
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth) == nil)
    }

    // MARK: - Edge cases

    @Test func swapErrorDescriptionsAreLocalized() {
        #expect(SwapMovementError.sameCrypto.errorDescription?.isEmpty == false)
        #expect(SwapMovementError.insufficientHoldings.errorDescription?.isEmpty == false)
    }

    @Test func swapWithZeroAmountsIsAccepted() async throws {
        let (context, portfolio, wallet, btc, eth) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc, cantidad: 5)

        let result = try await useCase.execute(
            input(
                cantidadOrigen: 0,
                cantidadDestino: 0,
                cartera: wallet,
                cryptoOrigen: btc,
                cryptoDestino: eth
            )
        )

        #expect(result.salida.cantidadOrigen == 0)
        #expect(result.entrada.cantidadDestino == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: wallet, crypto: eth) == nil)
    }
}

// MARK: - Fakes

/// `HoldingServiceProtocol` whose `updateHoldingForMovement(_:in:)` throws,
/// forcing the transaction to roll back after the movement inserts.
private struct ThrowingOnSwapHoldingService: HoldingServiceProtocol {
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
