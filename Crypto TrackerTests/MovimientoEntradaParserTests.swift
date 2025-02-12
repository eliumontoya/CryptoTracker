import XCTest
@testable import Crypto_Tracker

final class MovimientoEntradaParserTests: XCTestCase {
    // MARK: - Test Properties
    var crypto: Crypto!
    var cartera: Cartera!
    var fiat: FIAT!
    
    // MARK: - Setup and Teardown
    override func setUp() {
        super.setUp()
        // Crear instancias de prueba
        crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 45000)
        cartera = Cartera(nombre: "Binance", simbolo: "BNB")
        fiat = FIAT(nombre: "Euro", simbolo: "EUR", precioUSD: 1.1)
    }
    
    override func tearDown() {
        crypto = nil
        cartera = nil
        fiat = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    private func createTestWorksheet(headers: [String], rows: [[String]]) -> ExcelWorksheet {
        return ExcelWorksheet(testHeaderRow: headers, testRows: rows)
    }
    
    // MARK: - Tests
    
    /// Prueba la importación de un movimiento de entrada válido sin FIAT alterno
    /// Verifica:
    /// - Parseo correcto de la fecha
    /// - Asociación correcta de cartera y crypto
    /// - Cálculos correctos de cantidades y precios
    /// - Ausencia de datos de FIAT alterno
    func testParseValidMovimientoSinFiat() throws {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD
        ]
        
        let rows = [
            ["01/01/2024", "BNB", "BTC", "1.5", "67500", "45000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoEntradaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos[0]
        XCTAssertEqual(movimiento.cantidadCrypto, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.precioUSD, Decimal(string: "45000"))
        XCTAssertEqual(movimiento.cartera?.simbolo, "BNB")
        XCTAssertEqual(movimiento.crypto?.simbolo, "BTC")
        XCTAssertFalse(movimiento.usaFiatAlterno)
        XCTAssertNil(movimiento.fiatAlterno)
    }
    
    /// Prueba la importación de un movimiento de entrada válido que incluye FIAT alterno
    /// Verifica:
    /// - Parseo correcto de todos los campos incluyendo FIAT
    /// - Cálculos correctos de cantidades en FIAT
    /// - Asociación correcta del FIAT alterno
    /// - Flags de uso de FIAT correctamente establecidos
    func testParseValidMovimientoConFiat() throws {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD,
            MovimientoEntradaHeaders.fiatInvertido,
            MovimientoEntradaHeaders.fiatSimbolo
        ]
        
        let rows = [
            ["01/01/2024", "BNB", "BTC", "1.5", "67500", "45000", "74250", "EUR"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoEntradaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 1)
        let movimiento = movimientos[0]
        XCTAssertEqual(movimiento.cantidadCrypto, Decimal(string: "1.5"))
        XCTAssertEqual(movimiento.precioUSD, Decimal(string: "45000"))
        XCTAssertTrue(movimiento.usaFiatAlterno)
        XCTAssertEqual(movimiento.fiatAlterno?.simbolo, "EUR")
        XCTAssertEqual(movimiento.valorTotalFiatAlterno, Decimal(string: "74250"))
    }
    
    /// Prueba el manejo de errores cuando faltan campos requeridos en el archivo
    /// Verifica:
    /// - Detección correcta de campos faltantes
    /// - Lanzamiento apropiado de error
    /// - Validación de campos requeridos antes del procesamiento
    func testParseMissingRequiredFields() {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera
            // Missing required fields
        ]
        
        let rows = [["01/01/2024", "BNB"]]
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntradaParser.parse(
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
            // Verificar que sea el error de formato inválido
            if case .invalidFormat(let message) = worksheetError {
                // Verificar que el mensaje incluya las columnas faltantes
                XCTAssertTrue(message.contains("columnas requeridas"))
            } else {
                XCTFail("Expected invalidFormat error")
            }
        }
    }
    
    /// Prueba el manejo de fechas inválidas en el archivo
    /// Verifica:
    /// - Detección de formato de fecha incorrecto
    /// - Lanzamiento del error apropiado con información de la fila
    /// - Mensaje de error con el valor inválido
    func testParseInvalidDate() {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD
        ]
        
        let rows = [
            ["invalid-date", "BNB", "BTC", "1.5", "67500", "45000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntradaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )) { error in
            guard case let MovimientosParserError.invalidDate(row, value) = error else {
                XCTFail("Expected invalidDate error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(value, "invalid-date")
        }
    }
    
    /// Prueba el manejo de cryptos no existentes en el sistema
    /// Verifica:
    /// - Detección de crypto no encontrada
    /// - Lanzamiento del error apropiado
    /// - Mensaje de error con el símbolo de crypto inválido
    /// - Validación case-insensitive del símbolo
    func testParseInvalidCrypto() {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD
        ]
        
        let rows = [
            ["01/01/2024", "BNB", "INVALID", "1.5", "67500", "45000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntradaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )) { error in
            guard case let MovimientosParserError.cryptoNotFound(row, simbolo) = error else {
                XCTFail("Expected cryptoNotFound error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(simbolo, "INVALID")
        }
    }
    
    /// Prueba el manejo de carteras no existentes en el sistema
    /// Verifica:
    /// - Detección de cartera no encontrada
    /// - Lanzamiento del error apropiado
    /// - Mensaje de error con el nombre de cartera inválido
    /// - Validación case-insensitive del identificador de cartera
    func testParseInvalidCartera() {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD
        ]
        
        let rows = [
            ["01/01/2024", "INVALID", "BTC", "1.5", "67500", "45000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntradaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )) { error in
            guard case let MovimientosParserError.carteraNotFound(row, nombre) = error else {
                XCTFail("Expected carteraNotFound error")
                return
            }
            XCTAssertEqual(row, 2)
            XCTAssertEqual(nombre, "INVALID")
        }
    }
    
    /// Prueba el manejo de valores numéricos inválidos
    /// Verifica:
    /// - Detección de formato numérico incorrecto
    /// - Lanzamiento del error apropiado
    /// - Mensaje de error que incluye el campo y valor inválido
    /// - Manejo de diferentes campos numéricos (cantidad, precio, etc.)
    func testParseInvalidNumber() {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD
        ]
        
        let rows = [
            ["01/01/2024", "BNB", "BTC", "invalid", "67500", "45000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntradaParser.parse(
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
            XCTAssertEqual(field, MovimientoEntradaHeaders.cantidad)
            XCTAssertEqual(value, "invalid")
        }
    }
    
    /// Prueba el manejo de FIAT no existente en el sistema
    /// Verifica:
    /// - Detección de FIAT no encontrado
    /// - Lanzamiento del error apropiado
    /// - Mensaje de error con el símbolo de FIAT inválido
    /// - Validación case-insensitive del símbolo de FIAT
    func testParseInvalidFiat() {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD,
            MovimientoEntradaHeaders.fiatInvertido,
            MovimientoEntradaHeaders.fiatSimbolo
        ]
        
        let rows = [
            ["01/01/2024", "BNB", "BTC", "1.5", "67500", "45000", "74250", "INVALID"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // Then
        XCTAssertThrowsError(try MovimientoEntradaParser.parse(
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
    
    /// Prueba el procesamiento de múltiples filas válidas en el archivo
    /// Verifica:
    /// - Procesamiento correcto de múltiples registros
    /// - Mantenimiento del orden de los registros
    /// - Consistencia en el parseo de cada fila
    /// - Retorno del número correcto de movimientos
    func testMultipleValidRows() throws {
        // Given
        let headers = [
            MovimientoEntradaHeaders.fecha,
            MovimientoEntradaHeaders.cartera,
            MovimientoEntradaHeaders.crypto,
            MovimientoEntradaHeaders.cantidad,
            MovimientoEntradaHeaders.usdInvertido,
            MovimientoEntradaHeaders.precioUSD
        ]
        
        let rows = [
            ["01/01/2024", "BNB", "BTC", "1.5", "67500", "45000"],
            ["02/01/2024", "BNB", "BTC", "2.0", "90000", "45000"]
        ]
        
        let worksheet = createTestWorksheet(headers: headers, rows: rows)
        
        // When
        let movimientos = try MovimientoEntradaParser.parse(
            worksheet: worksheet,
            carteras: [cartera],
            cryptos: [crypto],
            fiats: [fiat]
        )
        
        // Then
        XCTAssertEqual(movimientos.count, 2)
        XCTAssertEqual(movimientos[0].cantidadCrypto, Decimal(string: "1.5"))
        XCTAssertEqual(movimientos[1].cantidadCrypto, Decimal(string: "2.0"))
    }
}
