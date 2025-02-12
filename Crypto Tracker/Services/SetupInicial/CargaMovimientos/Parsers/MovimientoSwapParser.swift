import Foundation
import SwiftData

struct MovimientoSwapHeaders {
    static let fecha = "Fecha"
    static let cartera = "ID_Cartera"
    static let cryptoOrigen = "Cripto origen"
    static let montoOrigen = "Monto Descontado"
    static let cryptoDestino = "Cripto final"
    static let montoDestino = "Monto Adquirido"
    static let precioVenta = "precio de venta"
    static let precioCompra = "precio de compra"
    
    static let required = [
        fecha, cartera, cryptoOrigen, montoOrigen,
        cryptoDestino, montoDestino, precioVenta, precioCompra
    ]
}

class MovimientoSwapParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    static func parse(
        worksheet: ExcelWorksheet,
        carteras: [Cartera],
        cryptos: [Crypto]
    ) throws -> [MovimientoSwap] {
        print("🔍 Validando encabezados del archivo de swaps...")
        try worksheet.validateHeaders(MovimientoSwapHeaders.required)
        
        let headers = Dictionary(uniqueKeysWithValues: worksheet.headerRow.enumerated().map { ($1, $0) })
        var movimientos: [MovimientoSwap] = []
        
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
                    cryptos: cryptos
                )
                movimientos.append(movimiento)
                print("✅ Fila \(currentRow) procesada correctamente")
            } catch {
                print("❌ Error en fila \(currentRow): \(error.localizedDescription)")
                throw error
            }
        }
        
        print("✅ Procesamiento completado. Total swaps: \(movimientos.count)")
        return movimientos
    }
    
    private static func parseRow(
        row: [String],
        rowIndex: Int,
        headers: [String: Int],
        carteras: [Cartera],
        cryptos: [Crypto]
    ) throws -> MovimientoSwap {
        // Fecha
        guard let fechaStr = row[safe: headers[MovimientoSwapHeaders.fecha] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !fechaStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.fecha)
        }
        
        guard let fecha = dateFormatter.date(from: fechaStr) else {
            throw MovimientosParserError.invalidDate(row: rowIndex, value: fechaStr)
        }
        
        // Cartera
        guard let carteraNombre = row[safe: headers[MovimientoSwapHeaders.cartera] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !carteraNombre.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.cartera)
        }
        
        let carteraId = carteraNombre.uppercased()
        guard let cartera = carteras.first(where: { $0.simbolo.uppercased() == carteraId }) else {
            throw MovimientosParserError.carteraNotFound(row: rowIndex, nombre: carteraId)
        }
        
        // Crypto Origen
        guard let cryptoOrigenSimbolo = row[safe: headers[MovimientoSwapHeaders.cryptoOrigen] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !cryptoOrigenSimbolo.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.cryptoOrigen)
        }
        
        let cryptoOrigenId = cryptoOrigenSimbolo.uppercased()
        guard let cryptoOrigen = cryptos.first(where: { $0.simbolo.uppercased() == cryptoOrigenId }) else {
            throw MovimientosParserError.cryptoNotFound(row: rowIndex, simbolo: cryptoOrigenId)
        }
        
        // Crypto Destino
        guard let cryptoDestinoSimbolo = row[safe: headers[MovimientoSwapHeaders.cryptoDestino] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !cryptoDestinoSimbolo.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.cryptoDestino)
        }
        
        let cryptoDestinoId = cryptoDestinoSimbolo.uppercased()
        guard let cryptoDestino = cryptos.first(where: { $0.simbolo.uppercased() == cryptoDestinoId }) else {
            throw MovimientosParserError.cryptoNotFound(row: rowIndex, simbolo: cryptoDestinoId)
        }
        
        // Validar que las cryptos sean diferentes
        if cryptoOrigen.id == cryptoDestino.id {
            throw MovimientosParserError.sameCrypto(row: rowIndex, crypto: cryptoOrigen.simbolo)
        }
        
        // Montos y Precios
        guard let montoOrigenStr = row[safe: headers[MovimientoSwapHeaders.montoOrigen] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !montoOrigenStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.montoOrigen)
        }
        
        guard let montoOrigen = Decimal(string: montoOrigenStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoSwapHeaders.montoOrigen,
                value: montoOrigenStr
            )
        }
        
        guard let montoDestinoStr = row[safe: headers[MovimientoSwapHeaders.montoDestino] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !montoDestinoStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.montoDestino)
        }
        
        guard let montoDestino = Decimal(string: montoDestinoStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoSwapHeaders.montoDestino,
                value: montoDestinoStr
            )
        }
        
        // Precios
        guard let precioVentaStr = row[safe: headers[MovimientoSwapHeaders.precioVenta] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !precioVentaStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.precioVenta)
        }
        
        guard let precioVenta = Decimal(string: precioVentaStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoSwapHeaders.precioVenta,
                value: precioVentaStr
            )
        }
        
        guard let precioCompraStr = row[safe: headers[MovimientoSwapHeaders.precioCompra] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !precioCompraStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSwapHeaders.precioCompra)
        }
        
        guard let precioCompra = Decimal(string: precioCompraStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoSwapHeaders.precioCompra,
                value: precioCompraStr
            )
        }
        
        // Verificar fondos disponibles
        let disponible = cartera.getCryptoDisponible(crypto: cryptoOrigen)
        if montoOrigen > disponible {
            throw MovimientosParserError.insufficientFunds(
                row: rowIndex,
                crypto: cryptoOrigen.simbolo,
                requested: montoOrigen,
                available: disponible
            )
        }
        
        return MovimientoSwap(
            fecha: fecha,
            cantidadOrigen: montoOrigen,
            cantidadDestino: montoDestino,
            precioUSDOrigen: precioVenta,
            precioUSDDestino: precioCompra,
            cartera: cartera,
            cryptoOrigen: cryptoOrigen,
            cryptoDestino: cryptoDestino
        )
    }
}
