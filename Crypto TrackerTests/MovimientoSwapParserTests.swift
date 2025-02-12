import XCTest
import SwiftData
@testable import Crypto_Tracker

final class MovimientoSwapParserTests: XCTestCase {
    // MARK: - Test Properties
    var cryptoOrigen: Crypto!
    var cryptoDestino: Crypto!
    var cartera: Cartera!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    // MARK: - Setup and Teardown
    override func setUp() {
        super.setUp()
        // Crear instancias de prueba
        cryptoOrigen = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 45000)
        cryptoDestino = Crypto(nombre: "Ethereum", simbolo: "ETH", precio: 2500)
        cartera = Cartera(nombre: "Binance", simbolo: "BNB")
        
        // Simular un balance en la cartera
        let movimientoInicial = MovimientoIngreso(
            fecha: Date(),
            cantidadCrypto: 2.0,
            precioUSD: 45000,
            cartera: cartera,
            crypto: cryptoOrigen
        )
        
        // Configurar el ModelContainer y ModelContext
        let schema = Schema([
            MovimientoIngreso.self,
            MovimientoSwap.self,
            Crypto.self,
            Cartera.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Insertar las entidades en el contexto
        modelContext.insert(cryptoOrigen)
        modelContext.insert(cryptoDestino)
        modelContext.insert(cartera)
        modelContext.insert(movimientoInicial)
    }
    
    override func tearDown() {
        cryptoOrigen = nil
        cryptoDestino = nil
        cartera = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    private func createTestWorksheet(headers: [String], rows: [[String]]) -> ExcelWorksheet {
        return ExcelWorksheet(testHeaderRow: headers, testRows: rows)
    }
    
    // MARK: - Tests
    
    /// Prueba un swap válido
    /// Verifica:
    /// - Parseo correcto de la fecha
    /// - Asociación correcta de cartera y cryptos
    /// - Cálculos correctos de cantidades y precios
    func testParseValidSwap() throws {
        // Given
        let headers = MovimientoSwapHeaders.required
        let rows = [
            ["01/01/2024", "BNB", "BTC", "1.5", "ETH", "25.0", "45000", "2500"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoSwapParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [cryptoOrigen, cryptoDestino]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos[0]
        XCTAssertEqual(movimiento.cantidadOrigen, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.cantidadDestino, Decimal(string: "25.0"))
        XCTAssertEqual(movimiento.precioUSDOrigen, Decimal(string: "45000"))
        XCTAssertEqual(movimiento.precioUSDDestino, Decimal(string: "2500"))
        XCTAssertEqual(movimiento.cartera?.simbolo, "BNB")
        XCTAssertEqual(movimiento.cryptoOrigen?.simbolo, "BTC")
        XCTAssertEqual(movimiento.cryptoDestino?.simbolo, "ETH")
    }
    
    /// Prueba la validación de misma crypto
    /// Verifica:
    /// - Detección de swap entre la misma crypto
    /// - Error apropiado
    func testParseSameCrypto() {
        // Given
        let headers = MovimientoSwapHeaders.required
        let rows = [
            ["01/01/2024", "BNB", "BTC", "1.5", "BTC", "1.4", "45000", "45000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoSwapParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [cryptoOrigen, cryptoDestino]
        )) { error in
            guard case let MovimientosParserError.sameCrypto(row, symbol) = error else {
                XCTFail("Expected sameCrypto error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(symbol, "BTC")
        }
    }
    
    /// Prueba la validación de fondos insuficientes
    /// Verifica:
    /// - Detección de fondos insuficientes
    /// - Error apropiado con los montos disponibles
    func testParseFondosInsuficientes() {
        // Given
        let headers = MovimientoSwapHeaders.required
        let rows = [
            ["01/01/2024", "BNB", "BTC", "2.5", "ETH", "40.0", "45000", "2500"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoSwapParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [cryptoOrigen, cryptoDestino]
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
            MovimientoSwapHeaders.fecha,
            MovimientoSwapHeaders.cartera
            // Missing required fields
        ]
        
        let rows = [["01/01/2024", "BNB"]]
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Calcular las columnas que deberían faltar
        let expectedMissingColumns = Set(MovimientoSwapHeaders.required).subtracting([
            MovimientoSwapHeaders.fecha,
            MovimientoSwapHeaders.cartera
        ])
        
        // Then
        XCTAssertThrowsError(try MovimientoSwapParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [cryptoOrigen, cryptoDestino]
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
        let headers = MovimientoSwapHeaders.required
        let rows = [
            ["01/01/2024", "BNB", "BTC", "invalid", "ETH", "25.0", "45000", "2500"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoSwapParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [cryptoOrigen, cryptoDestino]
        )) { error in
            guard case let MovimientosParserError.invalidNumber(row, field, value) = error else {
                XCTFail("Expected invalidNumber error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(field, MovimientoSwapHeaders.montoOrigen)
            XCTAssertEqual(value, "invalid")
        }
    }
}
