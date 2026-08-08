import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `RegisterMovementUseCase` registers an entry movement + holding atomically:
/// entry fields, FIAT-alternate fields, `holding.updatedAt = movimiento.fecha`, and
/// rollback when the holding update fails mid-transaction.
@MainActor
struct RegisterMovementUseCaseTests {
    private func makeUseCase(context: ModelContext) -> RegisterMovementUseCase {
        RegisterMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: HoldingService()
        )
    }

    @discardableResult
    private func makeContext() throws -> (ModelContext, Portfolio, Cartera, Crypto, FIAT) {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        let eur = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
        context.insert(portfolio)
        context.insert(cartera)
        context.insert(btc)
        context.insert(eur)
        try context.save()
        return (context, portfolio, cartera, btc, eur)
    }

    private func holding(in context: ModelContext, portfolio: Portfolio, cartera: Cartera, crypto: Crypto) throws -> Holding? {
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    private func input(
        fecha: Date = Date(),
        cantidadCrypto: Decimal = 2,
        precioUSD: Decimal = 50_000,
        usaFiatAlterno: Bool = false,
        precioFiatAlterno: Decimal? = nil,
        valorTotalFiatAlterno: Decimal? = nil,
        cartera: Cartera,
        crypto: Crypto,
        fiatAlterno: FIAT? = nil
    ) -> RegisterMovementInput {
        RegisterMovementInput(
            fecha: fecha,
            cantidadCrypto: cantidadCrypto,
            precioUSD: precioUSD,
            usaFiatAlterno: usaFiatAlterno,
            precioFiatAlterno: precioFiatAlterno,
            valorTotalFiatAlterno: valorTotalFiatAlterno,
            cartera: cartera,
            crypto: crypto,
            fiatAlterno: fiatAlterno
        )
    }

    // MARK: - Registro

    @Test func registerCreatesEntryMovementAndHolding() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)
        let useCase = makeUseCase(context: context)

        let movimiento = try await useCase.register(
            input(fecha: fecha, cantidadCrypto: 2, precioUSD: 50_000, cartera: cartera, crypto: btc)
        )

        // Movimiento persistido con tipo .entrada y campos correctos
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(movimiento.tipo == .entrada)
        #expect(movimiento.cantidadCrypto == 2)
        #expect(movimiento.precioUSD == 50_000)
        #expect(movimiento.valorTotalUSD == 100_000)
        #expect(movimiento.fecha == fecha)
        #expect(movimiento.crypto?.simbolo == "BTC")
        #expect(movimiento.cartera?.nombre == "Test Wallet")

        // Holding materializado: +cantidadCrypto
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
    }

    @Test func registerAccumulatesIntoExistingHolding() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await useCase.register(input(cantidadCrypto: 1, cartera: cartera, crypto: btc))
        try await useCase.register(input(cantidadCrypto: 1.5, cartera: cartera, crypto: btc))

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2.5)
    }

    // MARK: - FIAT alterno

    @Test func registerWithFiatAlternoPersistsAlternateFields() async throws {
        let (context, portfolio, cartera, btc, eur) = try makeContext()
        let useCase = makeUseCase(context: context)

        let movimiento = try await useCase.register(
            input(
                cantidadCrypto: 1,
                precioUSD: 45_454.55,
                usaFiatAlterno: true,
                precioFiatAlterno: 50_000,
                valorTotalFiatAlterno: 50_000,
                cartera: cartera,
                crypto: btc,
                fiatAlterno: eur
            )
        )

        #expect(movimiento.usaFiatAlterno)
        #expect(movimiento.fiatAlterno?.simbolo == "EUR")
        #expect(movimiento.precioFiatAlterno == 50_000)
        #expect(movimiento.valorTotalFiatAlterno == 50_000)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 1)
    }

    // MARK: - updatedAt = fecha

    @Test func registerStampsHoldingUpdatedAtWithMovementDate() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)
        let useCase = makeUseCase(context: context)

        try await useCase.register(input(fecha: fecha, cartera: cartera, crypto: btc))

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.updatedAt == fecha)
    }

    // MARK: - Atomicidad

    @Test func registerRollsBackMovementAndHoldingWhenHoldingUpdateFails() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = RegisterMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: context),
            holdingService: ThrowingHoldingService()
        )

        do {
            _ = try await useCase.register(input(cartera: cartera, crypto: btc))
            Issue.record("Expected register to throw")
        } catch is ThrowingHoldingService.Failure {
            // Esperado: el error del servicio propaga y nada se persiste.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    // MARK: - Edge cases

    @Test func registerWithZeroQuantityAndFiatAlternoPersistsMovementWithoutHoldingRow() async throws {
        let (context, portfolio, cartera, btc, eur) = try makeContext()
        let useCase = makeUseCase(context: context)

        let movimiento = try await useCase.register(
            input(
                cantidadCrypto: 0,
                precioUSD: 45_454.55,
                usaFiatAlterno: true,
                precioFiatAlterno: 50_000,
                valorTotalFiatAlterno: 0,
                cartera: cartera,
                crypto: btc,
                fiatAlterno: eur
            )
        )

        // El movimiento se persiste con cantidad 0 y sus campos FIAT alterno.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(movimiento.cantidadCrypto == 0)
        #expect(movimiento.usaFiatAlterno)
        #expect(movimiento.precioFiatAlterno == 50_000)
        #expect(movimiento.valorTotalFiatAlterno == 0)
        // Delta +0 no crea fila de holding.
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    @Test func registerWithZeroQuantityDoesNotAlterExistingHolding() async throws {
        let (context, portfolio, cartera, btc, eur) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await useCase.register(input(cantidadCrypto: 2, cartera: cartera, crypto: btc))
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)

        let fecha = Date(timeIntervalSince1970: 1_700_000_000)
        try await useCase.register(
            input(
                fecha: fecha,
                cantidadCrypto: 0,
                precioUSD: 45_454.55,
                usaFiatAlterno: true,
                precioFiatAlterno: 50_000,
                valorTotalFiatAlterno: 0,
                cartera: cartera,
                crypto: btc,
                fiatAlterno: eur
            )
        )

        // El holding existente no cambia, pero updatedAt se sella con la fecha del movimiento.
        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 2)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.updatedAt == fecha)
    }

    @Test func registerWithMaxValuesRoundTripsMovementAndHolding() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let maxQty: Decimal = 1_000_000_000_000
        let maxPrice: Decimal = 1_000_000_000_000

        let movimiento = try await useCase.register(
            input(cantidadCrypto: maxQty, precioUSD: maxPrice, cartera: cartera, crypto: btc)
        )

        #expect(movimiento.cantidadCrypto == maxQty)
        #expect(movimiento.precioUSD == maxPrice)
        #expect(movimiento.valorTotalUSD == maxQty * maxPrice)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == maxQty)
    }

    @Test func registerWithLegacyCarteraWithoutPortfolioPersistsMovementWithoutHolding() async throws {
        // Cartera "legacy" sin portfolio y sin portfolio por defecto en el contexto:
        // el movimiento se persiste, pero no se materializa fila de holding.
        let context = TestSetup.createModelContext()
        let cartera = Cartera(nombre: "Legacy Wallet", simbolo: "LEG")
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(cartera)
        context.insert(btc)
        try context.save()

        let useCase = makeUseCase(context: context)
        let movimiento = try await useCase.register(input(cartera: cartera, crypto: btc))

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(movimiento.cartera?.nombre == "Legacy Wallet")
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }

    // MARK: - Register salida

    @Test func registerSalidaCreatesExitMovementAndSubtractsHolding() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)
        let fecha = Date(timeIntervalSince1970: 1_700_000_000)

        // Seed an entry so the holding exists.
        try await useCase.register(input(cantidadCrypto: 5, precioUSD: 50_000, cartera: cartera, crypto: btc))
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 5)

        let movimiento = try await useCase.registerSalida(
            input(fecha: fecha, cantidadCrypto: 2, precioUSD: 60_000, cartera: cartera, crypto: btc)
        )

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 2)
        #expect(movimiento.tipo == .salida)
        #expect(movimiento.cantidadCrypto == 2)
        #expect(movimiento.precioUSD == 60_000)
        #expect(movimiento.valorTotalUSD == 120_000)
        #expect(movimiento.fecha == fecha)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 3)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.updatedAt == fecha)
    }

    @Test func registerSalidaDeletesHoldingAtZero() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await useCase.register(input(cantidadCrypto: 2, cartera: cartera, crypto: btc))
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)

        _ = try await useCase.registerSalida(input(cantidadCrypto: 2, cartera: cartera, crypto: btc))
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Crypto>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Crypto>()).first?.id == btc.id)
        #expect(try context.fetch(FetchDescriptor<Movimiento>()).allSatisfy { $0.crypto?.id == btc.id })
    }

    @Test func registerSalidaThrowsWhenHoldingIsMissing() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)

        do {
            _ = try await useCase.registerSalida(input(cantidadCrypto: 1, cartera: cartera, crypto: btc))
            Issue.record("Expected registerSalida to throw")
        } catch RegisterMovementError.insufficientHoldings {
            // Expected: no movement is inserted and the holding stays empty.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    @Test func registerSalidaThrowsWhenFundsAreInsufficient() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await useCase.register(input(cantidadCrypto: 2, cartera: cartera, crypto: btc))

        do {
            _ = try await useCase.registerSalida(input(cantidadCrypto: 3, cartera: cartera, crypto: btc))
            Issue.record("Expected registerSalida to throw")
        } catch RegisterMovementError.insufficientHoldings {
            // Expected: nothing is persisted.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
    }

    @Test func registerSalidaWithFiatAlternoPersistsAlternateFields() async throws {
        let (context, portfolio, cartera, btc, eur) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await useCase.register(input(cantidadCrypto: 2, cartera: cartera, crypto: btc))

        let movimiento = try await useCase.registerSalida(
            input(
                cantidadCrypto: 1,
                precioUSD: 45_454.55,
                usaFiatAlterno: true,
                precioFiatAlterno: 50_000,
                valorTotalFiatAlterno: 50_000,
                cartera: cartera,
                crypto: btc,
                fiatAlterno: eur
            )
        )

        #expect(movimiento.tipo == .salida)
        #expect(movimiento.usaFiatAlterno)
        #expect(movimiento.fiatAlterno?.simbolo == "EUR")
        #expect(movimiento.precioFiatAlterno == 50_000)
        #expect(movimiento.valorTotalFiatAlterno == 50_000)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 1)
    }

    @Test func registerSalidaRollsBackMovementAndHoldingWhenValidationFails() async throws {
        // Even if the holding update were to run before validation, the transaction must
        // roll back so the holding and movement remain unchanged.
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let useCase = makeUseCase(context: context)

        try await useCase.register(input(cantidadCrypto: 2, cartera: cartera, crypto: btc))

        do {
            _ = try await useCase.registerSalida(input(cantidadCrypto: 5, cartera: cartera, crypto: btc))
            Issue.record("Expected registerSalida to throw")
        } catch RegisterMovementError.insufficientHoldings {
            // Expected.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 1)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
    }
}

// MARK: - Fakes

/// `HoldingServiceProtocol` whose `updateHoldingForMovement(_:in:)` always throws,
/// forcing the transaction to roll back after the movement insert.
private struct ThrowingHoldingService: HoldingServiceProtocol {
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
