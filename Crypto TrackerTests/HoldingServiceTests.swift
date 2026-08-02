import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

/// Verifies `HoldingService` keeps the materialized `Holding` table in sync with
/// every movement type and that the `TransactionRunner` keeps movement + holding atomic.
@MainActor
struct HoldingServiceTests {
    private let service = HoldingService()

    // MARK: - Helpers

    @discardableResult
    private func makeContext() throws -> (ModelContext, Portfolio, Cartera, Crypto, Crypto) {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        let eth = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3_000)
        context.insert(portfolio)
        context.insert(cartera)
        context.insert(btc)
        context.insert(eth)
        try context.save()
        return (context, portfolio, cartera, btc, eth)
    }

    private func holding(in context: ModelContext, portfolio: Portfolio, cartera: Cartera, crypto: Crypto) throws -> Holding? {
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    // MARK: - Entrada / Salida

    @Test func entradaCreatesHolding() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let runner = ModelContextTransactionRunner(modelContext: context)

        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: 2, precioUSD: 50_000, cartera: cartera, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(entrada)
            try self.service.updateHoldingForMovement(entrada, in: ctx)
        }

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)
    }

    @Test func salidaDecrementsAndDeletesAtZero() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let runner = ModelContextTransactionRunner(modelContext: context)

        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: 5, precioUSD: 50_000, cartera: cartera, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(entrada)
            try self.service.updateHoldingForMovement(entrada, in: ctx)
        }

        let salida = Movimiento.salida(fecha: Date(), cantidadCrypto: 3, precioUSD: 50_000, cartera: cartera, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(salida)
            try self.service.updateHoldingForMovement(salida, in: ctx)
        }
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 2)

        // Venta total: la fila desaparece (cantidad <= 0)
        let salidaTotal = Movimiento.salida(fecha: Date(), cantidadCrypto: 2, precioUSD: 50_000, cartera: cartera, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(salidaTotal)
            try self.service.updateHoldingForMovement(salidaTotal, in: ctx)
        }
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    @Test func deleteHoldingRevertsEntrada() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let runner = ModelContextTransactionRunner(modelContext: context)

        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: 4, precioUSD: 50_000, cartera: cartera, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(entrada)
            try self.service.updateHoldingForMovement(entrada, in: ctx)
        }
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 4)

        try await runner.run { ctx in
            try self.service.deleteHoldingForMovement(entrada, in: ctx)
            ctx.delete(entrada)
        }
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
    }

    // MARK: - Transferencia (par de piernas)

    @Test func transferenciaMovesHoldingBetweenWallets() async throws {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let origen = Cartera(nombre: "Origen", simbolo: "ORI", portfolio: portfolio)
        let destino = Cartera(nombre: "Destino", simbolo: "DES", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(portfolio)
        context.insert(origen)
        context.insert(destino)
        context.insert(btc)
        try context.save()

        let runner = ModelContextTransactionRunner(modelContext: context)
        let par = Movimiento.transferencia(
            fecha: Date(),
            cantidadCryptoSalida: 10,
            cantidadCryptoEntrada: 9.5, // comisión 0.5
            carteraOrigen: origen,
            carteraDestino: destino,
            crypto: btc
        )
        try await runner.run { ctx in
            ctx.insert(par.salida)
            ctx.insert(par.entrada)
            try self.service.updateHoldingForMovement(par.salida, in: ctx)
            try self.service.updateHoldingForMovement(par.entrada, in: ctx)
        }

        // Origen: sin saldo previo → venta de 10 sin fila → se crea? No: delta negativo sin fila → nada.
        // Con saldo previo el comportamiento real es el que se prueba abajo.
        #expect(try holding(in: context, portfolio: portfolio, cartera: origen, crypto: btc) == nil)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destino, crypto: btc)?.cantidad == 9.5)
    }

    @Test func transferenciaDecrementsSourceHolding() async throws {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let origen = Cartera(nombre: "Origen", simbolo: "ORI", portfolio: portfolio)
        let destino = Cartera(nombre: "Destino", simbolo: "DES", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(portfolio)
        context.insert(origen)
        context.insert(destino)
        context.insert(btc)
        try context.save()

        let runner = ModelContextTransactionRunner(modelContext: context)
        // Saldo previo en origen: 20 BTC
        let previo = Movimiento.entrada(fecha: Date(), cantidadCrypto: 20, precioUSD: 50_000, cartera: origen, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(previo)
            try self.service.updateHoldingForMovement(previo, in: ctx)
        }

        let par = Movimiento.transferencia(
            fecha: Date(),
            cantidadCryptoSalida: 10,
            cantidadCryptoEntrada: 9.5,
            carteraOrigen: origen,
            carteraDestino: destino,
            crypto: btc
        )
        try await runner.run { ctx in
            ctx.insert(par.salida)
            ctx.insert(par.entrada)
            try self.service.updateHoldingForMovement(par.salida, in: ctx)
            try self.service.updateHoldingForMovement(par.entrada, in: ctx)
        }

        #expect(try holding(in: context, portfolio: portfolio, cartera: origen, crypto: btc)?.cantidad == 10)
        #expect(try holding(in: context, portfolio: portfolio, cartera: destino, crypto: btc)?.cantidad == 9.5)
    }

    // MARK: - Swap (par de piernas)

    @Test func swapMovesHoldingBetweenCryptos() async throws {
        let (context, portfolio, cartera, btc, eth) = try makeContext()
        let runner = ModelContextTransactionRunner(modelContext: context)

        // Saldo previo: 1 BTC
        let previo = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 50_000, cartera: cartera, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(previo)
            try self.service.updateHoldingForMovement(previo, in: ctx)
        }

        let par = Movimiento.swap(
            fecha: Date(),
            cantidadOrigen: 1,
            cantidadDestino: 16.66,
            precioUSDOrigen: 50_000,
            precioUSDDestino: 3_000,
            cartera: cartera,
            cryptoOrigen: btc,
            cryptoDestino: eth
        )
        try await runner.run { ctx in
            ctx.insert(par.salida)
            ctx.insert(par.entrada)
            try self.service.updateHoldingForMovement(par.salida, in: ctx)
            try self.service.updateHoldingForMovement(par.entrada, in: ctx)
        }

        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc) == nil)
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: eth)?.cantidad == 16.66)
    }

    // MARK: - Edición (snapshot previo)

    @Test func editRevertsPreviousAndAppliesNewEffect() async throws {
        let (context, portfolio, cartera, btc, _) = try makeContext()
        let runner = ModelContextTransactionRunner(modelContext: context)

        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: 3, precioUSD: 50_000, cartera: cartera, crypto: btc)
        try await runner.run { ctx in
            ctx.insert(entrada)
            try self.service.updateHoldingForMovement(entrada, in: ctx)
        }
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 3)

        // Editar 3 → 5 BTC: snapshot antes de mutar, aplicar con `previous`
        let previous = service.snapshot(of: entrada)
        try await runner.run { ctx in
            entrada.cantidadCrypto = 5
            entrada.valorTotalUSD = 250_000
            try self.service.updateHoldingForMovement(entrada, previous: previous, in: ctx)
        }
        #expect(try holding(in: context, portfolio: portfolio, cartera: cartera, crypto: btc)?.cantidad == 5)
    }

    // MARK: - Atomicidad con TransactionRunner

    @Test func failedBlockRollsBackMovementAndHolding() async throws {
        let context = TestSetup.createModelContext()
        let portfolio = Portfolio(nombre: "Test Portfolio", isDefault: true)
        let cartera = Cartera(nombre: "Test Wallet", simbolo: "TEST", portfolio: portfolio)
        let btc = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        context.insert(portfolio)
        context.insert(cartera)
        context.insert(btc)
        try context.save()

        let runner = ModelContextTransactionRunner(modelContext: context)
        struct BlockError: Error {}

        let entrada = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 50_000, cartera: cartera, crypto: btc)
        do {
            _ = try await runner.run { ctx in
                ctx.insert(entrada)
                try self.service.updateHoldingForMovement(entrada, in: ctx)
                throw BlockError()
            }
            Issue.record("Expected run to throw")
        } catch is BlockError {
            // Esperado: nada debe persistir.
        }

        #expect(try context.fetchCount(FetchDescriptor<Movimiento>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
    }
}
