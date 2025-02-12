import XCTest
import SwiftData
@testable import Crypto_Tracker

final class MovimientoSalidaParserTests: XCTestCase {
    // MARK: - Test Properties
    var crypto: Crypto!
    var cartera: Cartera!
    var fiat: FIAT!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    // MARK: - Setup and Teardown
    override func setUp() {
        super.setUp()
        // Crear instancias de prueba
        crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 45000)
        cartera = Cartera(nombre: "Binance", simbolo: "BNB")
        fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
        
        // Simular un balance en la cartera
        let movimientoInicial = MovimientoIngreso(
            fecha: Date(),
            cantidadCrypto: 2.0,
            precioUSD: 45000,
            cartera: cartera,
            crypto: crypto
        )
        
        // Configurar el ModelContainer y ModelContext
        let schema = Schema([
            MovimientoIngreso.self,
            MovimientoEgreso.self,
            Crypto.self,
            Cartera.self,
            FIAT.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Insertar las entidades en el contexto
        modelContext.insert(crypto)
        modelContext.insert(cartera)
        modelContext.insert(fiat)
        modelContext.insert(movimientoInicial)
    }
    
    override func tearDown() {
        crypto = nil
        cartera = nil
        fiat = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    private func createTestWorksheet(headers: [String], rows: [[String]]) -> ExcelWorksheet {
        return ExcelWorksheet(testHeaderRow: headers, testRows: rows)
    }
    
    // MARK: - Tests
    
    /// Prueba una salida válida sin FIAT
    /// Verifica:
    /// - Parseo correcto de la fecha
    /// - Asociación correcta de cartera y crypto
    /// - Cálculos correctos de cantidades y precios
    /// - Ausencia de datos de FIAT
    func testParseValidMovimientoSinFiat() throws {
        // Given
        let headers = MovimientoSalidaHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "1.5", "46000", "69000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos[0]
        XCTAssertEqual(movimiento.cantidadCrypto, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.precioUSD, Decimal(string: "46000"))
        XCTAssertEqual(movimiento.cartera?.simbolo, "BNB")
        XCTAssertEqual(movimiento.crypto?.simbolo, "BTC")
        XCTAssertFalse(movimiento.usaFiatAlterno)
        XCTAssertNil(movimiento.fiatAlterno)
    }
    
    /// Prueba una salida válida con FIAT
    /// Verifica:
    /// - Parseo correcto de todos los campos incluyendo FIAT
    /// - Cálculos correctos de cantidades en FIAT
    /// - Asociación correcta del FIAT
    func testParseValidMovimientoConFiat() throws {
        // Given
        let headers = MovimientoSalidaHeaders.required + [
            MovimientoSalidaHeaders.fiatRecibido,
            MovimientoSalidaHeaders.fiatSimbolo
        ]
        let rows = [
            ["01/01/2024", "BTC", "BNB", "1.5", "46000", "69000", "75900", "EUR"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos[0]
        XCTAssertEqual(movimiento.cantidadCrypto, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.precioUSD, Decimal(string: "46000"))
        XCTAssertTrue(movimiento.usaFiatAlterno)
        XCTAssertEqual(movimiento.fiatAlterno?.simbolo, "EUR")
        XCTAssertEqual(movimiento.valorTotalFiatAlterno, Decimal(string: "75900"))
    }
    
    /// Prueba la validación de fondos insuficientes
    /// Verifica:
    /// - Detección de fondos insuficientes
    /// - Error apropiado con los montos disponibles
    func testParseFondosInsuficientes() {
        // Given
        let headers = MovimientoSalidaHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "2.5", "46000", "115000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )) { error in
            guard case let MovimientosParserError.insufficientFunds(row, symbol, requested, available) = error else {
                XCTFail("Expected insufficientFunds error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(symbol, "BTC")
            XCTAssertEqual(requested, Decimal(string: "2.5"))
            XCTAssertEqual(available, Decimal(string: "2.0"))
        }
    }
    
    /// Prueba de campos requeridos faltantes
    /// Verifica:
    /// - Detección de campos faltantes
    /// - Mensaje de error apropiado con lista de campos faltantes
    func testParseMissingRequiredFields() {
        // Given
        let headers = [
            MovimientoSalidaHeaders.fecha,
            MovimientoSalidaHeaders.crypto
            // Missing required fields
        ]
        
        let rows = [["01/01/2024", "BTC"]]
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Calcular las columnas que deberían faltar
        let expectedMissingColumns = Set(MovimientoSalidaHeaders.required).subtracting([
            MovimientoSalidaHeaders.fecha,
            MovimientoSalidaHeaders.crypto
        ])
        
        // Then
        XCTAssertThrowsError(try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )) { error in
            XCTAssertTrue(error is ExcelWorksheetError)
            guard let worksheetError = error as? ExcelWorksheetError else {
                XCTFail("Expected ExcelWorksheetError")
                return
            }
            
            if case .invalidFormat(let message) = worksheetError {
                // Verificar que el mensaje incluye la frase general
                XCTAssertTrue(message.contains("Faltan las siguientes columnas requeridas"))
                
                // Verificar que cada columna faltante está mencionada en el mensaje
                for column in expectedMissingColumns {
                    XCTAssertTrue(message.contains(column),
                        "El mensaje debería mencionar la columna faltante: \(column)")
                }
                
                print("❌ Mensaje de error recibido:")
                print(message)
                print("📋 Columnas que deberían faltar: \(expectedMissingColumns.joined(separator: ", "))")
            } else {
                XCTFail("Expected invalidFormat error")
            }
        }
    }
    
    /// Prueba valores numéricos inválidos
    /// Verifica:
    /// - Detección de formato numérico incorrecto
    /// - Error apropiado con información del campo inválido
    func testParseInvalidNumber() {
        // Given
        let headers = MovimientoSalidaHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "invalid", "46000", "69000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )) { error in
            guard case let MovimientosParserError.invalidNumber(row, field, value) = error else {
                XCTFail("Expected invalidNumber error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(field, MovimientoSalidaHeaders.cantidad)
            XCTAssertEqual(value, "invalid")
        }
    }
    
    /// Prueba FIAT inválido
    /// Verifica:
    /// - Detección de FIAT no encontrado
    /// - Error apropiado con el símbolo inválido
    func testParseInvalidFiat() {
        // Given
        let headers = MovimientoSalidaHeaders.required + [
            MovimientoSalidaHeaders.fiatRecibido,
            MovimientoSalidaHeaders.fiatSimbolo
        ]
        let rows = [
            ["01/01/2024", "BTC", "BNB", "1.5", "46000", "69000", "75900", "INVALID"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )) { error in
            guard case let MovimientosParserError.fiatNotFound(row, simbolo) = error else {
                XCTFail("Expected fiatNotFound error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(simbolo, "INVALID")
        }
    }
}
