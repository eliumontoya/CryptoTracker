import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class PortfolioViewModelTests: XCTestCase {
    private var modelContext: ModelContext!
    private var viewModel: PortfolioViewModel!

    override func setUp() {
        super.setUp()
        modelContext = TestSetup.createModelContext()
        viewModel = PortfolioViewModel(modelContext: modelContext)
    }

    override func tearDown() {
        viewModel = nil
        modelContext = nil
        super.tearDown()
    }

    func testLoadPortfolioWithNoDataLeavesSummaryNil() {
        viewModel.loadPortfolio()
        XCTAssertNil(viewModel.summary)
        XCTAssertTrue(viewModel.distribution.isEmpty)
        XCTAssertTrue(viewModel.snapshots.isEmpty)
    }

    func testLoadPortfolioCalculatesSummaryForDefaultPortfolio() async throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: 1)
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 40000, cartera: cartera, crypto: crypto)

        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        modelContext.insert(holding)
        modelContext.insert(movimiento)
        try modelContext.save()

        viewModel.loadPortfolio()
        // Allow async snapshot task to complete
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(viewModel.summary)
        XCTAssertEqual(viewModel.summary?.valorActualUSD, 50000)
        XCTAssertEqual(viewModel.distribution.count, 1)
        XCTAssertEqual(viewModel.snapshots.count, 1)
    }
}

@MainActor
final class PortfolioPorCryptosViewModelTests: XCTestCase {
    private var modelContext: ModelContext!
    private var viewModel: PortfolioPorCryptosViewModel!

    override func setUp() {
        super.setUp()
        modelContext = TestSetup.createModelContext()
        let registerUseCase = RegisterMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: modelContext),
            holdingService: HoldingService()
        )
        let editUseCase = EditMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: modelContext),
            holdingService: HoldingService()
        )
        let deleteUseCase = DeleteMovementUseCase(
            transactionRunner: ModelContextTransactionRunner(modelContext: modelContext),
            holdingService: HoldingService()
        )
        viewModel = PortfolioPorCryptosViewModel(
            modelContext: modelContext,
            registerUseCase: registerUseCase,
            editUseCase: editUseCase,
            deleteUseCase: deleteUseCase
        )
    }

    override func tearDown() {
        viewModel = nil
        modelContext = nil
        super.tearDown()
    }

    func testActualizarPortfolioWithNoDataIsEmpty() {
        viewModel.actualizarPortfolio()
        XCTAssertTrue(viewModel.cryptoSummaries.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testActualizarPortfolioPopulatesCryptoSummaries() throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: 1)
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 40000, cartera: cartera, crypto: crypto)

        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        modelContext.insert(holding)
        modelContext.insert(movimiento)
        try modelContext.save()

        viewModel.actualizarPortfolio()

        XCTAssertEqual(viewModel.cryptoSummaries.count, 1)
        XCTAssertEqual(viewModel.cryptoSummaries.first?.crypto.simbolo, "BTC")
        XCTAssertFalse(viewModel.isLoading)
    }
}

@MainActor
final class CryptoDetailViewModelTests: XCTestCase {
    func testTitleIncludesCryptoNameAndSymbol() {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let viewModel = CryptoDetailViewModel(crypto: crypto, carteras: [])
        XCTAssertEqual(viewModel.title, "Bitcoin (BTC)")
    }

    func testCargarMovimientosWithSingleEntry() throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 40000, cartera: cartera, crypto: crypto)
        cartera.movimientos.append(movimiento)

        let viewModel = CryptoDetailViewModel(crypto: crypto, carteras: [cartera])
        viewModel.cargarMovimientos()

        XCTAssertEqual(viewModel.movimientos.count, 1)
        XCTAssertEqual(viewModel.movimientos.first?.tipo, .entrada)
        XCTAssertEqual(viewModel.movimientos.first?.valorUSD, 40000)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testCargarMovimientosIgnoresUnrelatedCrypto() throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let bitcoin = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let ethereum = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 3000)
        let movimiento = Movimiento.entrada(fecha: Date(), cantidadCrypto: 1, precioUSD: 40000, cartera: cartera, crypto: ethereum)
        cartera.movimientos.append(movimiento)

        let viewModel = CryptoDetailViewModel(crypto: bitcoin, carteras: [cartera])
        viewModel.cargarMovimientos()

        XCTAssertTrue(viewModel.movimientos.isEmpty)
    }
}

@MainActor
final class CarteraDetailViewModelTests: XCTestCase {
    func testComputedProperties() {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let cryptoDetail = CryptoDetail(
            crypto: crypto,
            totalCryptoIngresado: 1,
            totalCryptoVendido: 0,
            totalCryptoTransferido: 0,
            balanceActual: 1,
            totalInvertidoUSD: 40000,
            valorUSD: 50000,
            ganancia: 10000
        )
        let carteraDetail = CarteraDetail(cartera: cartera, cryptoDetails: [cryptoDetail])

        var updated = false
        let viewModel = CarteraDetailViewModel(carteraDetail: carteraDetail) {
            updated = true
        }

        XCTAssertEqual(viewModel.carteraNombre, "Binance")
        XCTAssertEqual(viewModel.valorTotalUSD, Format.usd(Decimal(50000)))
        XCTAssertEqual(viewModel.gananciaTotal, Format.usd(Decimal(10000)))
        XCTAssertTrue(viewModel.isGananciaPositive)
        XCTAssertEqual(viewModel.cryptoDetails.count, 1)

        viewModel.updateData()
        XCTAssertTrue(updated)
    }
}

@MainActor
final class CarteraCryptoDetailViewModelTests: XCTestCase {
    func testTitleAndSubtitle() {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB")
        let viewModel = CarteraCryptoDetailViewModel(crypto: crypto, cartera: cartera)

        XCTAssertEqual(viewModel.title, "Bitcoin (BTC)")
        XCTAssertEqual(viewModel.subtitle, "Cartera: Binance")
    }

    func testCargarMovimientosWithSingleExit() {
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB")
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        let movimiento = Movimiento.salida(fecha: Date(), cantidadCrypto: 0.5, precioUSD: 50000, cartera: cartera, crypto: crypto)
        cartera.movimientos.append(movimiento)

        let viewModel = CarteraCryptoDetailViewModel(crypto: crypto, cartera: cartera)
        viewModel.cargarMovimientos()

        XCTAssertEqual(viewModel.movimientos.count, 1)
        XCTAssertEqual(viewModel.movimientos.first?.tipo, .salida)
        XCTAssertEqual(viewModel.movimientos.first?.carteraOrigen, "Binance")
        XCTAssertFalse(viewModel.isLoading)
    }
}
