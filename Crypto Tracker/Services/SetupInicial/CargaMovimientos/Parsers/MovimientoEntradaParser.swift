import Foundation
import SwiftData

struct MovimientoEntradaHeaders {
    static let fecha = "Fecha"
    static let cartera = "ID_Cartera"
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

class MovimientoEntradaParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    static func parse(
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
            let currentRow = rowIndex + 2
            do {
                print("📝 Procesando fila \(currentRow)...")
                let movimiento = try parseRow(
                    row: row,
                    rowIndex: currentRow,
                    headers: headers,
                    carteras: carteras,
                    cryptos: cryptos,
                    fiats: fiats
                )
                movimientos.append(movimiento)
                print("✅ Fila \(currentRow) procesada correctamente")
            } catch {
                print("❌ Error en fila \(currentRow): \(error.localizedDescription)")
                throw error
            }
        }
        
        print("✅ Procesamiento completado. Total movimientos: \(movimientos.count)")
        return movimientos
    }
    
    private static func parseRow(
        row: [String],
        rowIndex: Int,
        headers: [String: Int],
        carteras: [Cartera],
        cryptos: [Crypto],
        fiats: [FIAT]
    ) throws -> MovimientoIngreso {
        // Fecha
        guard let fechaStr = row[safe: headers[MovimientoEntradaHeaders.fecha] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !fechaStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntradaHeaders.fecha)
        }
        
        guard let fecha = dateFormatter.date(from: fechaStr) else {
            throw MovimientosParserError.invalidDate(row: rowIndex, value: fechaStr)
        }
        
        // Cartera
        guard let carteraNombre = row[safe: headers[MovimientoEntradaHeaders.cartera] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !carteraNombre.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntradaHeaders.cartera)
        }
        
        let carteraId = carteraNombre.uppercased()
        guard let cartera = carteras.first(where: { $0.simbolo.uppercased() == carteraId }) else {
            throw MovimientosParserError.carteraNotFound(row: rowIndex, nombre: carteraId)
        }
        
        // Crypto
        guard let cryptoSimbolo = row[safe: headers[MovimientoEntradaHeaders.crypto] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !cryptoSimbolo.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntradaHeaders.crypto)
        }
        
        let cryptoId = cryptoSimbolo.uppercased()
        guard let crypto = cryptos.first(where: { $0.simbolo.uppercased() == cryptoId }) else {
            throw MovimientosParserError.cryptoNotFound(row: rowIndex, simbolo: cryptoId)
        }
        
        // Cantidad
        guard let cantidadStr = row[safe: headers[MovimientoEntradaHeaders.cantidad] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !cantidadStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntradaHeaders.cantidad)
        }
        
        guard let cantidadCrypto = Decimal(string: cantidadStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoEntradaHeaders.cantidad,
                value: cantidadStr
            )
        }
        
        // Precio USD
        guard let precioUSDStr = row[safe: headers[MovimientoEntradaHeaders.precioUSD] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !precioUSDStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntradaHeaders.precioUSD)
        }
        
        guard let precioUSD = Decimal(string: precioUSDStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoEntradaHeaders.precioUSD,
                value: precioUSDStr
            )
        }
        
        // FIAT opcional
        let (usaFiatAlterno, fiatAlterno, valorTotalFiatAlterno) = try parseFiatOpcional(
            row: row,
            headers: headers,
            rowIndex: rowIndex,
            fiats: fiats,
            cantidadCrypto: cantidadCrypto
        )
        
        return MovimientoIngreso(
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
    }
    
    private static func parseFiatOpcional(
        row: [String],
        headers: [String: Int],
        rowIndex: Int,
        fiats: [FIAT],
        cantidadCrypto: Decimal
    ) throws -> (usa: Bool, fiat: FIAT?, valor: Decimal?) {
        if let valorFiatStr = row[safe: headers[MovimientoEntradaHeaders.fiatInvertido] ?? -1]?.trimmingCharacters(in: .whitespaces),
           let simboloFiat = row[safe: headers[MovimientoEntradaHeaders.fiatSimbolo] ?? -1]?.trimmingCharacters(in: .whitespaces),
           !valorFiatStr.isEmpty,
           !simboloFiat.isEmpty {
            
            guard let valorFiat = Decimal(string: valorFiatStr) else {
                throw MovimientosParserError.invalidNumber(
                    row: rowIndex,
                    field: MovimientoEntradaHeaders.fiatInvertido,
                    value: valorFiatStr
                )
            }
            
            let simboloFiatUppercase = simboloFiat.uppercased()
            guard let fiat = fiats.first(where: { $0.simbolo.uppercased() == simboloFiatUppercase }) else {
                throw MovimientosParserError.fiatNotFound(row: rowIndex, simbolo: simboloFiatUppercase)
            }
            
            return (true, fiat, valorFiat)
        }
        
        return (false, nil, nil)
    }
}
