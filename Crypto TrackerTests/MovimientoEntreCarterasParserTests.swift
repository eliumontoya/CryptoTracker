import XCTest
import SwiftData
@testable import Crypto_Tracker

final class MovimientoEntreCarterasParserTests: XCTestCase {
    // MARK: - Test Properties
    var crypto: Crypto!
    var carteraOrigen: Cartera!
    var carteraDestino: Cartera!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    // MARK: - Setup and Teardown
    override func setUp() {
        super.setUp()
        // Crear instancias de prueba
        crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 45000)
        carteraOrigen = Cartera(nombre: "Binance", simbolo: "BNB")
        carteraDestino = Cartera(nombre: "MetaMask", simbolo: "MM")
        
        // Simular un balance en la cartera origen
        let movimientoInicial = MovimientoIngreso(
            fecha: Date(),
            cantidadCrypto: 2.0,
            precioUSD: 45000,
            cartera: carteraOrigen,
            crypto: crypto
        )
        
        // Configurar el ModelContainer y ModelContext
        let schema = Schema([
            MovimientoIngreso.self,
            Crypto.self,
            Cartera.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Insertar las entidades en el contexto
        modelContext.insert(crypto)
        modelContext.insert(carteraOrigen)
        modelContext.insert(carteraDestino)
        modelContext.insert(movimientoInicial)
    }
    
    override func tearDown() {
        crypto = nil
        carteraOrigen = nil
        carteraDestino = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    private func createTestWorksheet(headers: [String], rows: [[String]]) -> ExcelWorksheet {
        return ExcelWorksheet(testHeaderRow: headers, testRows: rows)
    }
    
    // MARK: - Tests
    
    /// Prueba un movimiento entre carteras válido sin comisión
    /// Verifica:
    /// - Parseo correcto de la fecha
    /// - Asociación correcta de carteras y crypto
    /// - Cantidades de envío y recepción correctas
    func testParseValidMovimientoSinComision() throws {
        // Given
        let headers = MovimientoEntreCarterasHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "MM", "1.5", "1.5"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: [carteraOrigen, carteraDestino],
            cryptos: [crypto]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos[0]
        XCTAssertEqual(movimiento.cantidadCryptoSalida, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.cantidadCryptoEntrada, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.carteraOrigen?.simbolo, "BNB")
        XCTAssertEqual(movimiento.carteraDestino?.simbolo, "MM")
        XCTAssertEqual(movimiento.crypto?.simbolo, "BTC")
        XCTAssertEqual(movimiento.cantidadCryptoComision, 0)
    }
    
    /// Prueba un movimiento entre carteras válido con comisión
    /// Verifica:
    /// - Cálculo correcto de la comisión
    /// - Validación de montos de envío y recepción
    func testParseValidMovimientoConComision() throws {
        // Given
        let headers = MovimientoEntreCarterasHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "MM", "1.5", "1.45"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: [carteraOrigen, carteraDestino],
            cryptos: [crypto]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos[0]
        XCTAssertEqual(movimiento.cantidadCryptoSalida, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.cantidadCryptoEntrada, Decimal(string: "1.45"))
        XCTAssertEqual(movimiento.cantidadCryptoComision, Decimal(string: "0.05"))
    }
    
    /// Prueba la validación de carteras iguales
    /// Verifica:
    /// - Detección de transferencia a la misma cartera
    /// - Error apropiado
    func testParseMismaCartera() {
        // Given
        let headers = MovimientoEntreCarterasHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "BNB", "1.5", "1.5"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: [carteraOrigen, carteraDestino],
            cryptos: [crypto]
        )) { error in
            guard case let MovimientosParserError.sameWallet(row) = error else {
                XCTFail("Expected sameWallet error")
                return
            }
            XCTAssertEqual(row, 2)
        }
    }
    
    /// Prueba la validación de monto recibido mayor al enviado
    /// Verifica:
    /// - Detección de monto recibido inválido
    /// - Error apropiado con los montos incorrectos
    func testParseMontoRecibidoMayorQueEnviado() {
        // Given
        let headers = MovimientoEntreCarterasHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "MM", "1.5", "1.6"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: [carteraOrigen, carteraDestino],
            cryptos: [crypto]
        )) { error in
            guard case let MovimientosParserError.invalidReceivedAmount(row, sent, received) = error else {
                XCTFail("Expected invalidReceivedAmount error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(sent, Decimal(string: "1.5"))
            XCTAssertEqual(received, Decimal(string: "1.6"))
        }
    }
    
    /// Prueba la validación de fondos insuficientes
    /// Verifica:
    /// - Detección de fondos insuficientes
    /// - Error apropiado con los montos disponibles
    func testParseFondosInsuficientes() {
        // Given
        let headers = MovimientoEntreCarterasHeaders.required
        let rows = [
            ["01/01/2024", "BTC", "BNB", "MM", "2.5", "2.4"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: [carteraOrigen, carteraDestino],
            cryptos: [crypto]
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
    /// - Mensaje de error apropiado
    func testParseMissingRequiredFields() {
        // Given
        let headers = [
            MovimientoEntreCarterasHeaders.fecha,
            MovimientoEntreCarterasHeaders.crypto
            // Missing required fields
        ]
        
        let rows = [["01/01/2024", "BTC"]]
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Calcular las columnas que deberían faltar
        let expectedMissingColumns = Set(MovimientoEntreCarterasHeaders.required).subtracting([
            MovimientoEntreCarterasHeaders.fecha,
            MovimientoEntreCarterasHeaders.crypto
        ])
        
        // Then
        XCTAssertThrowsError(try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: [carteraOrigen, carteraDestino],
            cryptos: [crypto]
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
}
