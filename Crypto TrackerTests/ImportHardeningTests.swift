import XCTest
import SwiftData
@testable import Crypto_Tracker

final class ExcelReaderHardeningTests: XCTestCase {
    func testAlignedRowPreservesEmptyColumns() {
        let row = ExcelWorksheet.alignedRow(valuesByColumn: [
            "A": "first",
            "C": "third",
            "AA": "twenty-seventh"
        ])

        XCTAssertEqual(row.count, 27)
        XCTAssertEqual(row[0], "first")
        XCTAssertEqual(row[1], "")
        XCTAssertEqual(row[2], "third")
        XCTAssertEqual(row[26], "twenty-seventh")
    }

    func testReaderAcceptsReadableLocalFileWithoutSecurityScope() async throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data-example/entradas_carga.xlsx")

        let worksheet = try await ExcelReader.read(from: fixture)

        XCTAssertEqual(worksheet.headerRow, MovimientoEntradaHeaders.required)
        XCTAssertEqual(worksheet.rows.first?.count, worksheet.headerRow.count)
    }

    func testReaderPreservesTrailingEmptyCellFromRealFixture() async throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data-example/salidas_carga.xlsx")

        let worksheet = try await ExcelReader.read(from: fixture)

        XCTAssertEqual(worksheet.rows.first?.count, worksheet.headerRow.count)
        XCTAssertEqual(worksheet.rows.first?[safe: 5], "")
    }
}

final class MovimientoSalidaContractTests: XCTestCase {
    func testDerivesUSDTotalWhenColumnIsEmpty() throws {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        let cartera = Cartera(nombre: "Wallet", simbolo: "WALLET")
        let worksheet = ExcelWorksheet(
            testHeaderRow: MovimientoSalidaHeaders.required + [MovimientoSalidaHeaders.valorTotalUSD],
            testRows: [["01/01/2025", "BTC", "WALLET", "2", "50000", ""]]
        )

        let movement = try XCTUnwrap(MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [],
            skipFundCheck: true
        ).first)

        XCTAssertEqual(movement.valorTotalUSD, Decimal(100_000))
    }

    func testKeepsProvidedUSDTotalWhenConsistentWithinTolerance() throws {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        let cartera = Cartera(nombre: "Wallet", simbolo: "WALLET")
        let worksheet = ExcelWorksheet(
            testHeaderRow: MovimientoSalidaHeaders.required + [MovimientoSalidaHeaders.valorTotalUSD],
            testRows: [["01/01/2025", "BTC", "WALLET", "2", "50000", "100000.005"]]
        )

        let movement = try XCTUnwrap(MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [],
            skipFundCheck: true
        ).first)

        XCTAssertEqual(movement.valorTotalUSD, Decimal(string: "100000.005"))
    }

    func testRejectsProvidedUSDTotalWhenInconsistent() {
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        let cartera = Cartera(nombre: "Wallet", simbolo: "WALLET")
        let worksheet = ExcelWorksheet(
            testHeaderRow: MovimientoSalidaHeaders.required + [MovimientoSalidaHeaders.valorTotalUSD],
            testRows: [["01/01/2025", "BTC", "WALLET", "2", "50000", "90000"]]
        )

        XCTAssertThrowsError(try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [],
            skipFundCheck: true
        )) { error in
            guard case MovimientosParserError.invalidFormat = error else {
                return XCTFail("Expected invalidFormat, got \(error)")
            }
        }
    }

    func testRealSalidaFixtureParsesByDerivingMissingTotal() async throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data-example/salidas_carga.xlsx")
        let worksheet = try await ExcelReader.read(from: fixture)
        let crypto = Crypto(nombre: "AIXBT", simbolo: "AIXBT", precio: 1)
        let cartera = Cartera(nombre: "Phantom", simbolo: "Phan")

        let movement = try XCTUnwrap(MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [],
            skipFundCheck: true
        ).first)

        XCTAssertEqual(movement.valorTotalUSD, movement.cantidadCrypto * movement.precioUSD)
    }
}

@MainActor
final class CargaMovimientosBatchServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var crypto: Crypto!
    private var cartera: Cartera!
    private var fiat: FIAT!

    override func setUpWithError() throws {
        let schema = Schema([
            FIAT.self, Crypto.self, Cartera.self, Portfolio.self, Holding.self,
            Movimiento.self, PrecioHistorico.self, PortfolioSnapshot.self, CryptoSyncConfig.self
        ])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)
        let portfolio = Portfolio(nombre: "Main", isDefault: true)
        crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50_000)
        cartera = Cartera(nombre: "Wallet", simbolo: "WALLET", portfolio: portfolio)
        fiat = FIAT(nombre: "US Dollar", simbolo: "USD", precioUSD: 1)
        context.insert(portfolio)
        context.insert(crypto)
        context.insert(cartera)
        context.insert(fiat)
        try context.save()
    }

    override func tearDown() {
        fiat = nil
        cartera = nil
        crypto = nil
        context = nil
        container = nil
    }

    func testInvalidSecondFileLeavesNoPartialImport() async throws {
        let entradaURL = URL(fileURLWithPath: "/entrada.xlsx")
        let salidaURL = URL(fileURLWithPath: "/salida.xlsx")
        let service = makeService(worksheets: [
            entradaURL: entradaWorksheet(),
            salidaURL: ExcelWorksheet(
                testHeaderRow: MovimientoSalidaHeaders.required + [MovimientoSalidaHeaders.valorTotalUSD],
                testRows: [["01/01/2025", "BTC", "WALLET", "1", "50000", "40000"]]
            )
        ])

        do {
            _ = try await service.cargar(
                archivos: CargaMovimientosFileSelection(
                    entrada: entradaURL, salida: salidaURL, entreCarteras: nil, swap: nil
                ),
                cryptos: [crypto],
                carteras: [cartera],
                fiats: [fiat]
            )
            XCTFail("Expected the batch to fail")
        } catch {
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movimiento>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Holding>()), 0)
        }
    }

    func testSuccessfulRetryDoesNotDuplicateMovementsOrHoldings() async throws {
        let entradaURL = URL(fileURLWithPath: "/entrada.xlsx")
        let service = makeService(worksheets: [entradaURL: entradaWorksheet()])
        let selection = CargaMovimientosFileSelection(
            entrada: entradaURL, salida: nil, entreCarteras: nil, swap: nil
        )

        let first = try await service.cargar(
            archivos: selection, cryptos: [crypto], carteras: [cartera], fiats: [fiat]
        )
        let second = try await service.cargar(
            archivos: selection, cryptos: [crypto], carteras: [cartera], fiats: [fiat]
        )

        XCTAssertEqual(first["Movimientos de Entrada"], 1)
        XCTAssertEqual(second["Movimientos de Entrada"], 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movimiento>()), 1)
        let holding = try XCTUnwrap(context.fetch(FetchDescriptor<Holding>()).first)
        XCTAssertEqual(holding.cantidad, 1)
    }

    func testEntryOneThenExitTwoRollsBackEntireBatch() async throws {
        let entradaURL = URL(fileURLWithPath: "/entrada.xlsx")
        let salidaURL = URL(fileURLWithPath: "/salida.xlsx")
        let service = makeService(worksheets: [
            entradaURL: entradaWorksheet(date: "01/01/2025", quantity: "1"),
            salidaURL: salidaWorksheet(date: "02/01/2025", quantity: "2")
        ])

        await assertNegativeReplay(
            service: service,
            selection: CargaMovimientosFileSelection(
                entrada: entradaURL, salida: salidaURL, entreCarteras: nil, swap: nil
            ),
            cryptos: [crypto],
            wallets: [cartera]
        )
    }

    func testExitWithoutHoldingRollsBackEntireBatch() async throws {
        let salidaURL = URL(fileURLWithPath: "/salida.xlsx")
        let service = makeService(worksheets: [
            salidaURL: salidaWorksheet(date: "01/01/2025", quantity: "1")
        ])

        await assertNegativeReplay(
            service: service,
            selection: CargaMovimientosFileSelection(
                entrada: nil, salida: salidaURL, entreCarteras: nil, swap: nil
            ),
            cryptos: [crypto],
            wallets: [cartera]
        )
    }

    func testTransferWithInsufficientOriginFundsRollsBackEntireBatch() async throws {
        let destination = makeDestinationWallet()
        let entradaURL = URL(fileURLWithPath: "/entrada.xlsx")
        let transferURL = URL(fileURLWithPath: "/transfer.xlsx")
        let service = makeService(worksheets: [
            entradaURL: entradaWorksheet(date: "01/01/2025", quantity: "1"),
            transferURL: transferWorksheet(date: "02/01/2025", sent: "2", received: "2")
        ])

        await assertNegativeReplay(
            service: service,
            selection: CargaMovimientosFileSelection(
                entrada: entradaURL, salida: nil, entreCarteras: transferURL, swap: nil
            ),
            cryptos: [crypto],
            wallets: [cartera, destination]
        )
    }

    func testTransferWithoutOriginHoldingRollsBackEntireBatch() async throws {
        let destination = makeDestinationWallet()
        let transferURL = URL(fileURLWithPath: "/transfer.xlsx")
        let service = makeService(worksheets: [
            transferURL: transferWorksheet(date: "01/01/2025", sent: "1", received: "1")
        ])

        await assertNegativeReplay(
            service: service,
            selection: CargaMovimientosFileSelection(
                entrada: nil, salida: nil, entreCarteras: transferURL, swap: nil
            ),
            cryptos: [crypto],
            wallets: [cartera, destination]
        )
    }

    func testSwapWithInsufficientOriginFundsRollsBackEntireBatch() async throws {
        let ethereum = makeEthereum()
        let entradaURL = URL(fileURLWithPath: "/entrada.xlsx")
        let swapURL = URL(fileURLWithPath: "/swap.xlsx")
        let service = makeService(worksheets: [
            entradaURL: entradaWorksheet(date: "01/01/2025", quantity: "1"),
            swapURL: swapWorksheet(date: "02/01/2025", origin: "2")
        ])

        await assertNegativeReplay(
            service: service,
            selection: CargaMovimientosFileSelection(
                entrada: entradaURL, salida: nil, entreCarteras: nil, swap: swapURL
            ),
            cryptos: [crypto, ethereum],
            wallets: [cartera]
        )
    }

    func testSwapWithoutOriginHoldingRollsBackEntireBatch() async throws {
        let ethereum = makeEthereum()
        let swapURL = URL(fileURLWithPath: "/swap.xlsx")
        let service = makeService(worksheets: [
            swapURL: swapWorksheet(date: "01/01/2025", origin: "1")
        ])

        await assertNegativeReplay(
            service: service,
            selection: CargaMovimientosFileSelection(
                entrada: nil, salida: nil, entreCarteras: nil, swap: swapURL
            ),
            cryptos: [crypto, ethereum],
            wallets: [cartera]
        )
    }

    func testReplayAllowsExactZeroAndRemovesHolding() async throws {
        let entradaURL = URL(fileURLWithPath: "/entrada.xlsx")
        let salidaURL = URL(fileURLWithPath: "/salida.xlsx")
        let service = makeService(worksheets: [
            entradaURL: entradaWorksheet(date: "01/01/2025", quantity: "1"),
            salidaURL: salidaWorksheet(date: "02/01/2025", quantity: "1")
        ])

        let result = try await service.cargar(
            archivos: CargaMovimientosFileSelection(
                entrada: entradaURL, salida: salidaURL, entreCarteras: nil, swap: nil
            ),
            cryptos: [crypto],
            carteras: [cartera],
            fiats: [fiat]
        )

        XCTAssertEqual(result["Movimientos de Entrada"], 1)
        XCTAssertEqual(result["Movimientos de Salida"], 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movimiento>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Holding>()), 0)
    }

    func testTransferImportRejectsExistingPartialPairWithoutChangingStore() async throws {
        let destination = Cartera(nombre: "Destination", simbolo: "DEST", portfolio: cartera.portfolio)
        context.insert(destination)
        let seed = Movimiento.entrada(
            fecha: Date(timeIntervalSince1970: 0),
            cantidadCrypto: 10,
            precioUSD: 50_000,
            cartera: cartera,
            crypto: crypto
        )
        let existingPair = Movimiento.transferencia(
            fecha: importDate(),
            cantidadCryptoSalida: 3,
            cantidadCryptoEntrada: 3,
            carteraOrigen: cartera,
            carteraDestino: destination,
            crypto: crypto
        )
        context.insert(seed)
        context.insert(existingPair.salida)
        try context.save()
        context.delete(existingPair.entrada)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movimiento>()), 2)
        let url = URL(fileURLWithPath: "/transfer.xlsx")
        let service = makeService(worksheets: [url: transferWorksheet()])

        do {
            _ = try await service.cargar(
                archivos: CargaMovimientosFileSelection(
                    entrada: nil, salida: nil, entreCarteras: url, swap: nil
                ),
                cryptos: [crypto],
                carteras: [cartera, destination],
                fiats: [fiat]
            )
            XCTFail("Expected partial transfer rejection")
        } catch {
            XCTAssertEqual(error as? CargaMovimientosBatchError, .incompleteExistingPair)
            let stored = try context.fetch(FetchDescriptor<Movimiento>())
            XCTAssertEqual(stored.count, 2)
            XCTAssertEqual(stored.filter { $0.groupId == existingPair.salida.groupId }.count, 1)
        }
    }

    func testSwapImportRejectsExistingPartialPairWithoutChangingStore() async throws {
        let ethereum = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 2_000)
        context.insert(ethereum)
        let seed = Movimiento.entrada(
            fecha: Date(timeIntervalSince1970: 0),
            cantidadCrypto: 10,
            precioUSD: 50_000,
            cartera: cartera,
            crypto: crypto
        )
        let existingPair = Movimiento.swap(
            fecha: importDate(),
            cantidadOrigen: 2,
            cantidadDestino: 50,
            precioUSDOrigen: 50_000,
            precioUSDDestino: 2_000,
            cartera: cartera,
            cryptoOrigen: crypto,
            cryptoDestino: ethereum
        )
        context.insert(seed)
        context.insert(existingPair.entrada)
        try context.save()
        context.delete(existingPair.salida)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Movimiento>()), 2)
        let url = URL(fileURLWithPath: "/swap.xlsx")
        let service = makeService(worksheets: [url: swapWorksheet()])

        do {
            _ = try await service.cargar(
                archivos: CargaMovimientosFileSelection(
                    entrada: nil, salida: nil, entreCarteras: nil, swap: url
                ),
                cryptos: [crypto, ethereum],
                carteras: [cartera],
                fiats: [fiat]
            )
            XCTFail("Expected partial swap rejection")
        } catch {
            XCTAssertEqual(error as? CargaMovimientosBatchError, .incompleteExistingPair)
            let stored = try context.fetch(FetchDescriptor<Movimiento>())
            XCTAssertEqual(stored.count, 2)
            XCTAssertEqual(stored.filter { $0.groupId == existingPair.entrada.groupId }.count, 1)
        }
    }

    private func makeService(worksheets: [URL: ExcelWorksheet]) -> CargaMovimientosBatchService {
        CargaMovimientosBatchService(
            modelContext: context,
            readWorksheet: { url in
                guard let worksheet = worksheets[url] else {
                    throw ExcelWorksheetError.fileNotFound(url.lastPathComponent)
                }
                return worksheet
            }
        )
    }

    private func entradaWorksheet(date: String = "01/01/2025", quantity: String = "1") -> ExcelWorksheet {
        ExcelWorksheet(
            testHeaderRow: MovimientoEntradaHeaders.required,
            testRows: [[date, "WALLET", "BTC", quantity, "50000", quantity == "1" ? "50000" : "100000"]]
        )
    }

    private func salidaWorksheet(date: String, quantity: String) -> ExcelWorksheet {
        ExcelWorksheet(
            testHeaderRow: MovimientoSalidaHeaders.required,
            testRows: [[date, "BTC", "WALLET", quantity, "50000"]]
        )
    }

    private func transferWorksheet(
        date: String = "01/01/2025",
        sent: String = "3",
        received: String = "3"
    ) -> ExcelWorksheet {
        ExcelWorksheet(
            testHeaderRow: MovimientoEntreCarterasHeaders.required,
            testRows: [[date, "BTC", "WALLET", "DEST", sent, received]]
        )
    }

    private func swapWorksheet(date: String = "01/01/2025", origin: String = "2") -> ExcelWorksheet {
        ExcelWorksheet(
            testHeaderRow: MovimientoSwapHeaders.required,
            testRows: [[date, "WALLET", "BTC", origin, "ETH", "50", "50000", "2000"]]
        )
    }

    private func makeDestinationWallet() -> Cartera {
        let destination = Cartera(nombre: "Destination", simbolo: "DEST", portfolio: cartera.portfolio)
        context.insert(destination)
        return destination
    }

    private func makeEthereum() -> Crypto {
        let ethereum = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 2_000)
        context.insert(ethereum)
        return ethereum
    }

    private func assertNegativeReplay(
        service: CargaMovimientosBatchService,
        selection: CargaMovimientosFileSelection,
        cryptos: [Crypto],
        wallets: [Cartera],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await service.cargar(
                archivos: selection,
                cryptos: cryptos,
                carteras: wallets,
                fiats: [fiat]
            )
            XCTFail("Expected negative replay rejection", file: file, line: line)
        } catch {
            XCTAssertEqual(
                error as? CargaMovimientosBatchError,
                .negativeBalance,
                file: file,
                line: line
            )
            XCTAssertEqual(
                try? context.fetchCount(FetchDescriptor<Movimiento>()),
                0,
                file: file,
                line: line
            )
            XCTAssertEqual(
                try? context.fetchCount(FetchDescriptor<Holding>()),
                0,
                file: file,
                line: line
            )
        }
    }

    private func importDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: "01/01/2025")!
    }
}

final class ImportFixtureSecurityTests: XCTestCase {
    func testSyncFixtureContainsNoAPIKeyQueryParameter() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data-example/sync_carga.csv")
        let contents = try String(contentsOf: fixture, encoding: .utf8).lowercased()

        XCTAssertFalse(contents.contains("x_cg_demo_api_key"))
        XCTAssertFalse(contents.contains("api_key="))
    }
}
