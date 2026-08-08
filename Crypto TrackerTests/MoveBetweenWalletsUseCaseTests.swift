import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `MoveBetweenWalletsUseCase` creates a pair of transfer movements
/// (`.transferenciaSalida` + `.transferenciaEntrada`) atomically, validates the
/// origin wallet has enough funds, updates materialized holdings, and rolls back
/// on failure.
@MainActor
struct MoveBetweenWalletsUseCaseTests {
    private func makeUseCase(context: ModelContext) -> MoveBetweenWalletsUseCase {
        MoveBetweenWalletsUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: HoldingService()
        )
    }

    @discardableResult
    private func makeContext() throws -> (ModelContext, Portfolio, Cartera, Cartera, Crypto) {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let origin = Cartera(nombre: "Origin Wallet", simbolo: "ORI", portfolio: portfolio)
        let destination = Cartera(nombre: "Destination Wallet", simbolo: "DES", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(portfolio)
        context.insert(origin)
        context.insert(destination)
        context.insert(btc)
        try context.save()
        return (context, portfolio, origin, destination, btc)
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
        cantidadCryptoSalida: Decimal = 2,
        cantidadCryptoEntrada: Decimal = 2,
        precioUSD: Decimal = 50_000,
        carteraOrigen: Cartera,
        carteraDestino: Cartera,
        crypto: Crypto
    ) -> MoveBetweenWalletsInput {
        MoveBetweenWalletsInput(
            fecha: fecha,
            cantidadCryptoSalida: cantidadCryptoSalida,
            cantidadCryptoEntrada: cantidadCryptoEntrada,
            precioUSD: precioUSD,
            carteraOrigen: carteraOrigen,
            carteraDestino: carteraDestino,
            crypto: crypto
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

    @Test func transferCreatesMovementPairWithSharedGroupId() async throws {
        let (context, _, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)

        try await seedHolding(in: context, portfolio: PortfolioQueries.defaultPortfolio(in: context)!, cartera: origin, crypto: btc, cantidad: 5)

        let result = try await useCase.execute(
            input(
                fecha: fecha,
                cantidadCryptoSalida: 2,
                cantidadCryptoEntrada: 1.5,
                precioUSD: 50_000,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        let movements = try context.fetch(FetchDescriptor<Movimiento>(sortBy: [SortDescriptor(\.tipoRaw)]))
        #expect(movements.count == 3) // seeded entry + transfer pair

        #expect(result.salida.tipo == .transferenciaSalida)
        #expect(result.entrada.tipo == .transferenciaEntrada)
        #expect(result.salida.groupId == result.entrada.groupId)
        #expect(result.salida.groupId != nil)

        #expect(result.salida.cantidadCryptoSalida == 2)
        #expect(result.salida.cantidadCryptoEntrada == 1.5)
        #expect(result.salida.cantidadCryptoComision == 0.5)
        #expect(result.entrada.cantidadCryptoSalida == 2)
        #expect(result.entrada.cantidadCryptoEntrada == 1.5)
        #expect(result.entrada.cantidadCryptoComision == 0.5)

        #expect(result.salida.carteraOrigen?.id == origin.id)
        #expect(result.salida.carteraDestino?.id == destination.id)
        #expect(result.entrada.carteraOrigen?.id == origin.id)
        #expect(result.entrada.carteraDestino?.id == destination.id)

        #expect(result.salida.crypto?.id == btc.id)
        #expect(result.entrada.crypto?.id == btc.id)

        #expect(result.salida.precioUSD == 50_000)
        #expect(result.salida.valorTotalUSD == Decimal(100_000))
        #expect(result.entrada.precioUSD == 50_000)
        #expect(result.entrada.valorTotalUSD == Decimal(75_000))

        #expect(result.salida.fecha == fecha)
        #expect(result.entrada.fecha == fecha)
    }

    @Test func transferMovesHoldingsBetweenWallets() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 10)

        _ = try await useCase.execute(
            input(
                cantidadCryptoSalida: 4,
                cantidadCryptoEntrada: 3.5,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: origin, crypto: btc)?.cantidad == 6)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.cantidad == 3.5)
    }

    @Test func transferWithZeroCommissionMovesEqualAmounts() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 5)

        let result = try await useCase.execute(
            input(
                cantidadCryptoSalida: 2,
                cantidadCryptoEntrada: 2,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        #expect(result.salida.cantidadCryptoComision == 0)
        #expect(result.entrada.cantidadCryptoComision == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: origin, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.cantidad == 2)
    }

    @Test func transferStampsHoldingsUpdatedAtWithMovementDate() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 5)

        _ = try await useCase.execute(
            input(
                fecha: fecha,
                cantidadCryptoSalida: 2,
                cantidadCryptoEntrada: 2,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: origin, crypto: btc)?.updatedAt == fecha)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.updatedAt == fecha)
    }

    @Test func transferDestinationHoldingCreatedWhenMissing() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc) == nil)

        _ = try await useCase.execute(
            input(
                cantidadCryptoSalida: 2,
                cantidadCryptoEntrada: 2,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.cantidad == 2)
    }

    @Test func transferOriginHoldingDeletedAtZero() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 2)

        _ = try await useCase.execute(
            input(
                cantidadCryptoSalida: 2,
                cantidadCryptoEntrada: 2,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        #expect(try holding(in: context, portfolio: portfolio, cartera: origin, crypto: btc) == nil)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc)?.cantidad == 2)
        #expect(try context.fetchCount(FetchDescriptor<Crypto>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Crypto>()).first?.id == btc.id)
        #expect(try context.fetch(FetchDescriptor<Movimiento>()).allSatisfy { $0.crypto?.id == btc.id })
    }

    // MARK: - Validation errors

    @Test func transferToSameWalletThrowsSameWalletError() async throws {
        let (context, _, origin, _, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        await #expect(throws: MoveBetweenWalletsError.sameWallet) {
            _ = try await useCase.execute(
                input(carteraOrigen: origin, carteraDestino: origin, crypto: btc)
            )
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    @Test func transferWithNegativeCommissionThrows() async throws {
        let (context, _, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        await #expect(throws: MoveBetweenWalletsError.negativeCommission) {
            _ = try await useCase.execute(
                input(
                    cantidadCryptoSalida: 2,
                    cantidadCryptoEntrada: 2.5,
                    carteraOrigen: origin,
                    carteraDestino: destination,
                    crypto: btc
                )
            )
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    @Test func transferWithMissingOriginHoldingThrowsInsufficientHoldings() async throws {
        let (context, _, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        await #expect(throws: MoveBetweenWalletsError.insufficientHoldings) {
            _ = try await useCase.execute(
                input(carteraOrigen: origin, carteraDestino: destination, crypto: btc)
            )
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    @Test func transferWithInsufficientFundsThrowsAndLeavesStoreUnchanged() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 1)

        await #expect(throws: MoveBetweenWalletsError.insufficientHoldings) {
            _ = try await useCase.execute(
                input(
                    cantidadCryptoSalida: 2,
                    cantidadCryptoEntrada: 2,
                    carteraOrigen: origin,
                    carteraDestino: destination,
                    crypto: btc
                )
            )
        }

        // Only the seeded entry exists, and the origin holding is untouched.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: origin, crypto: btc)?.cantidad == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc) == nil)
    }

    // MARK: - Atomicity

    @Test func transferRollsBackBothMovementsWhenHoldingUpdateFails() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = MoveBetweenWalletsUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: ThrowingOnTransferHoldingService()
        )

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 5)

        do {
            _ = try await useCase.execute(
                input(carteraOrigen: origin, carteraDestino: destination, crypto: btc)
            )
            Issue.record("Expected execute to throw")
        } catch is ThrowingOnTransferHoldingService.Failure {
            // Expected: both inserts are rolled back.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1) // seeded entry only
        #expect(try holding(in: context, portfolio: portfolio, cartera: origin, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc) == nil)
    }

    // MARK: - Edge cases

    @Test func transferErrorDescriptionsAreLocalized() {
        #expect(MoveBetweenWalletsError.sameWallet.errorDescription?.isEmpty == false)
        #expect(MoveBetweenWalletsError.negativeCommission.errorDescription?.isEmpty == false)
        #expect(MoveBetweenWalletsError.insufficientHoldings.errorDescription?.isEmpty == false)
    }

    @Test func transferWithZeroAmountsIsAccepted() async throws {
        let (context, portfolio, origin, destination, btc) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await seedHolding(in: context, portfolio: portfolio, cartera: origin, crypto: btc, cantidad: 5)

        let result = try await useCase.execute(
            input(
                cantidadCryptoSalida: 0,
                cantidadCryptoEntrada: 0,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        #expect(result.salida.cantidadCryptoSalida == 0)
        #expect(result.entrada.cantidadCryptoEntrada == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: origin, crypto: btc)?.cantidad == 5)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destination, crypto: btc) == nil)
    }

    @Test func transferWithDifferentWalletsInDifferentPortfolios() async throws {
        let context = TestSetup.createModelContext()
        let portfolioA = Portfolio(nombre: "Portfolio A", isDefault: false)
        let portfolioB = Portfolio(nombre: "Portfolio B", isDefault: false)
        let origin = Cartera(nombre: "Origin", simbolo: "ORI", portfolio: portfolioA)
        let destination = Cartera(nombre: "Destination", simbolo: "DES", portfolio: portfolioB)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(portfolioA)
        context.insert(portfolioB)
        context.insert(origin)
        context.insert(destination)
        context.insert(btc)
        try context.save()

        let useCase = makeUseCase(context: context)
        try await seedHolding(in: context, portfolio: portfolioA, cartera: origin, crypto: btc, cantidad: 5)

        _ = try await useCase.execute(
            input(
                cantidadCryptoSalida: 2,
                cantidadCryptoEntrada: 1.8,
                carteraOrigen: origin,
                carteraDestino: destination,
                crypto: btc
            )
        )

        #expect(try holding(in: context, portfolio: portfolioA, cartera: origin, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolioB, cartera: destination, crypto: btc)?.cantidad == 1.8)
    }
}

// MARK: - Fakes

/// `HoldingServiceProtocol` whose `updateHoldingForMovement(_:in:)` throws,
/// forcing the transaction to roll back after the movement inserts.
private struct ThrowingOnTransferHoldingService: HoldingServiceProtocol {
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
