import Foundation
import SwiftData

// MARK: - MovimientosParserError
enum MovimientosParserError: LocalizedError {
    case invalidDate(row: Int, value: String)
    case invalidNumber(row: Int, field: String, value: String)
    case carteraNotFound(row: Int, nombre: String)
    case cryptoNotFound(row: Int, simbolo: String)
    case fiatNotFound(row: Int, simbolo: String)
    case invalidFormat(String)
    case missingData(row: Int, field: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidDate(let row, let value):
            return "Error en fila \(row): La fecha '\(value)' no tiene el formato correcto (debe ser DD/MM/YYYY)"
        case .invalidNumber(let row, let field, let value):
            return "Error en fila \(row): El valor '\(value)' para '\(field)' no es un número válido"
        case .carteraNotFound(let row, let simbolo):
            return """
                Error en fila \(row): No se encontró la cartera con ID '\(simbolo)' en los catálogos.
                Asegúrese de usar el símbolo/ID de la cartera (ejemplo: BIN para Binance) y no el nombre completo.
                """
        case .cryptoNotFound(let row, let simbolo):
            return "Error en fila \(row): No se encontró la crypto '\(simbolo)' en los catálogos"
        case .fiatNotFound(let row, let simbolo):
            return "Error en fila \(row): No se encontró el FIAT '\(simbolo)' en los catálogos"
        case .invalidFormat(let message):
            return "Error de formato: \(message)"
        case .missingData(let row, let field):
            return "Error en fila \(row): Falta el valor para el campo '\(field)'"
        }
    }
}

// MARK: - MovimientosParser
class MovimientosParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    // MARK: - Headers Definitions
    struct MovimientoEntradaHeaders {
        static let fecha = "Fecha"
        static let cartera = "ID_Cartera"  // Cambiado para reflejar que es el ID/Simbolo
        static let crypto = "Cripto"
        static let cantidad = "Cripto adquirido"
        static let usdInvertido = "USD Invertido"
        static let precioUSD = "Costo Cripto / USD"
        static let fiatInvertido = "FIAT Invertido"
        static let fiatSimbolo = "FIAT_Simbolo"
        
        static let required = [
            fecha, cartera, crypto, cantidad, usdInvertido, precioUSD
        ]
    }
    
    // MARK: - Parsing Methods
    static func parseMovimientoEntrada(
        worksheet: ExcelWorksheet,
        carteras: [Cartera],
        cryptos: [Crypto],
        fiats: [FIAT]
    ) throws -> [MovimientoIngreso] {
        print("🔍 Validando encabezados del archivo...")
        try worksheet.validateHeaders(MovimientoEntradaHeaders.required)
        
        let headers = Dictionary(uniqueKeysWithValues: worksheet.headerRow.enumerated().map { ($1, $0) })
        var movimientos: [MovimientoIngreso] = []
        
        print("📊 Iniciando procesamiento de \(worksheet.rows.count) filas...")
        
        for (rowIndex, row) in worksheet.rows.enumerated() {
            let currentRow = rowIndex + 2 // +2 por headers y 0-based index
            do {
                print("📝 Procesando fila \(currentRow)...")
                
                // Obtener y validar la fecha
                guard let fechaStr = row[safe: headers[MovimientoEntradaHeaders.fecha] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !fechaStr.isEmpty else {
                    throw MovimientosParserError.missingData(row: currentRow, field: MovimientoEntradaHeaders.fecha)
                }
                
                guard let fecha = dateFormatter.date(from: fechaStr) else {
                    throw MovimientosParserError.invalidDate(row: currentRow, value: fechaStr)
                }
                
                // Obtener y validar la cartera
                                guard let carteraNombre = row[safe: headers[MovimientoEntradaHeaders.cartera] ?? -1]?.trimmingCharacters(in: .whitespaces),
                                      !carteraNombre.isEmpty else {
                                    throw MovimientosParserError.missingData(row: currentRow, field: MovimientoEntradaHeaders.cartera)
                                }
                
               
                
                let carteraId = carteraNombre.uppercased()
                               guard let cartera = carteras.first(where: { $0.simbolo.uppercased() == carteraId }) else {
                                   throw MovimientosParserError.carteraNotFound(row: currentRow, nombre: carteraId)
                               }
                               
                               // Obtener y validar la crypto
                               guard let cryptoSimbolo = row[safe: headers[MovimientoEntradaHeaders.crypto] ?? -1]?.trimmingCharacters(in: .whitespaces),
                                     !cryptoSimbolo.isEmpty else {
                                   throw MovimientosParserError.missingData(row: currentRow, field: MovimientoEntradaHeaders.crypto)
                               }
                               
                               let cryptoId = cryptoSimbolo.uppercased()
                               guard let crypto = cryptos.first(where: { $0.simbolo.uppercased() == cryptoId }) else {
                                   throw MovimientosParserError.cryptoNotFound(row: currentRow, simbolo: cryptoId)
                               }
                
                // Parsear cantidades numéricas
                guard let cantidadStr = row[safe: headers[MovimientoEntradaHeaders.cantidad] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !cantidadStr.isEmpty else {
                    throw MovimientosParserError.missingData(row: currentRow, field: MovimientoEntradaHeaders.cantidad)
                }
                
                guard let cantidadCrypto = Decimal(string: cantidadStr) else {
                    throw MovimientosParserError.invalidNumber(
                        row: currentRow,
                        field: MovimientoEntradaHeaders.cantidad,
                        value: cantidadStr
                    )
                }
                
                guard let valorTotalUSDStr = row[safe: headers[MovimientoEntradaHeaders.usdInvertido] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !valorTotalUSDStr.isEmpty else {
                    throw MovimientosParserError.missingData(row: currentRow, field: MovimientoEntradaHeaders.usdInvertido)
                }
                
                guard let valorTotalUSD = Decimal(string: valorTotalUSDStr) else {
                    throw MovimientosParserError.invalidNumber(
                        row: currentRow,
                        field: MovimientoEntradaHeaders.usdInvertido,
                        value: valorTotalUSDStr
                    )
                }
                
                guard let precioUSDStr = row[safe: headers[MovimientoEntradaHeaders.precioUSD] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !precioUSDStr.isEmpty else {
                    throw MovimientosParserError.missingData(row: currentRow, field: MovimientoEntradaHeaders.precioUSD)
                }
                
                guard let precioUSD = Decimal(string: precioUSDStr) else {
                    throw MovimientosParserError.invalidNumber(
                        row: currentRow,
                        field: MovimientoEntradaHeaders.precioUSD,
                        value: precioUSDStr
                    )
                }
                
                // Procesar FIAT opcional
                var usaFiatAlterno = false
                var fiatAlterno: FIAT?
                var valorTotalFiatAlterno: Decimal?
                
                if let valorFiatStr = row[safe: headers[MovimientoEntradaHeaders.fiatInvertido] ?? -1]?.trimmingCharacters(in: .whitespaces),
                   let simboloFiat = row[safe: headers[MovimientoEntradaHeaders.fiatSimbolo] ?? -1]?.trimmingCharacters(in: .whitespaces),
                   !valorFiatStr.isEmpty,
                   !simboloFiat.isEmpty {
                    
                    guard let valorFiat = Decimal(string: valorFiatStr) else {
                        throw MovimientosParserError.invalidNumber(
                            row: currentRow,
                            field: MovimientoEntradaHeaders.fiatInvertido,
                            value: valorFiatStr
                        )
                    }
                    
                    
                    let simboloFiatUppercase = simboloFiat.uppercased()
                                        guard let fiat = fiats.first(where: { $0.simbolo.uppercased() == simboloFiatUppercase }) else {
                                            throw MovimientosParserError.fiatNotFound(row: currentRow, simbolo: simboloFiatUppercase)
                                        }
                    
                    usaFiatAlterno = true
                    fiatAlterno = fiat
                    valorTotalFiatAlterno = valorFiat
                }
                
                let movimiento = MovimientoIngreso(
                    fecha: fecha,
                    cantidadCrypto: cantidadCrypto,
                    precioUSD: precioUSD,
                    usaFiatAlterno: usaFiatAlterno,
                    precioFiatAlterno: usaFiatAlterno ? (valorTotalFiatAlterno! / cantidadCrypto) : nil,
                    valorTotalFiatAlterno: valorTotalFiatAlterno,
                    cartera: cartera,
                    crypto: crypto,
                    fiatAlterno: fiatAlterno
                )
                
                movimientos.append(movimiento)
                print("✅ Fila \(currentRow) procesada correctamente")
                
            } catch {
                print("❌ Error en fila \(currentRow): \(error.localizedDescription)")
                throw error // Re-lanzar el error para que se maneje en el nivel superior
            }
        }
        
        print("✅ Procesamiento completado. Total movimientos: \(movimientos.count)")
        return movimientos
    }
}
