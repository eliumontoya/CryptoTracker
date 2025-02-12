import Foundation
import SwiftData

struct MovimientoEntreCarterasHeaders {
    static let fecha = "Fecha"
    static let crypto = "Cripto"
    static let carteraOrigen = "ID_Cartera_Origen"
    static let carteraDestino = "ID_Cartera_Destino"
    static let montoEnvio = "Monto Envio"
    static let montoRecibido = "Monto recibido"
    static let comision = "Comision"
    
    static let required = [
        fecha, crypto, carteraOrigen, carteraDestino, montoEnvio, montoRecibido
    ]
}

class MovimientoEntreCarterasParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    static func parse(
        worksheet: ExcelWorksheet,
        carteras: [Cartera],
        cryptos: [Crypto]
    ) throws -> [MovimientoEntreCarteras] {
        print("🔍 Validando encabezados del archivo de transferencias entre carteras...")
        try worksheet.validateHeaders(MovimientoEntreCarterasHeaders.required)
        
        let headers = Dictionary(uniqueKeysWithValues: worksheet.headerRow.enumerated().map { ($1, $0) })
        var movimientos: [MovimientoEntreCarteras] = []
        
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
        
        print("✅ Procesamiento completado. Total transferencias: \(movimientos.count)")
        return movimientos
    }
    
    private static func parseRow(
        row: [String],
        rowIndex: Int,
        headers: [String: Int],
        carteras: [Cartera],
        cryptos: [Crypto]
    ) throws -> MovimientoEntreCarteras {
        // Fecha
        guard let fechaStr = row[safe: headers[MovimientoEntreCarterasHeaders.fecha] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !fechaStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntreCarterasHeaders.fecha)
        }
        
        guard let fecha = dateFormatter.date(from: fechaStr) else {
            throw MovimientosParserError.invalidDate(row: rowIndex, value: fechaStr)
        }
        
        // Crypto
        guard let cryptoSimbolo = row[safe: headers[MovimientoEntreCarterasHeaders.crypto] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !cryptoSimbolo.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntreCarterasHeaders.crypto)
        }
        
        let cryptoId = cryptoSimbolo.uppercased()
        guard let crypto = cryptos.first(where: { $0.simbolo.uppercased() == cryptoId }) else {
            throw MovimientosParserError.cryptoNotFound(row: rowIndex, simbolo: cryptoId)
        }
        
        // Cartera Origen
        guard let carteraOrigenNombre = row[safe: headers[MovimientoEntreCarterasHeaders.carteraOrigen] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !carteraOrigenNombre.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntreCarterasHeaders.carteraOrigen)
        }
        
        let carteraOrigenId = carteraOrigenNombre.uppercased()
        guard let carteraOrigen = carteras.first(where: { $0.simbolo.uppercased() == carteraOrigenId }) else {
            throw MovimientosParserError.carteraNotFound(row: rowIndex, nombre: carteraOrigenId)
        }
        
        // Cartera Destino
        guard let carteraDestinoNombre = row[safe: headers[MovimientoEntreCarterasHeaders.carteraDestino] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !carteraDestinoNombre.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntreCarterasHeaders.carteraDestino)
        }
        
        let carteraDestinoId = carteraDestinoNombre.uppercased()
        guard let carteraDestino = carteras.first(where: { $0.simbolo.uppercased() == carteraDestinoId }) else {
            throw MovimientosParserError.carteraNotFound(row: rowIndex, nombre: carteraDestinoId)
        }
        
        // Validar que las carteras sean diferentes
        if carteraOrigen.id == carteraDestino.id {
            throw MovimientosParserError.sameWallet(row: rowIndex)
        }
        
        // Montos
        guard let montoEnvioStr = row[safe: headers[MovimientoEntreCarterasHeaders.montoEnvio] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !montoEnvioStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntreCarterasHeaders.montoEnvio)
        }
        
        guard let montoEnvio = Decimal(string: montoEnvioStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoEntreCarterasHeaders.montoEnvio,
                value: montoEnvioStr
            )
        }
        
        guard let montoRecibidoStr = row[safe: headers[MovimientoEntreCarterasHeaders.montoRecibido] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !montoRecibidoStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoEntreCarterasHeaders.montoRecibido)
        }
        
        guard let montoRecibido = Decimal(string: montoRecibidoStr) else {
            throw MovimientosParserError.invalidNumber(
                row: rowIndex,
                field: MovimientoEntreCarterasHeaders.montoRecibido,
                value: montoRecibidoStr
            )
        }
        
        // Validar que el monto recibido no sea mayor al enviado
        if montoRecibido > montoEnvio {
            throw MovimientosParserError.invalidReceivedAmount(
                row: rowIndex,
                sent: montoEnvio,
                received: montoRecibido
            )
        }
        
        // Verificar fondos disponibles
        let disponible = carteraOrigen.getCryptoDisponible(crypto: crypto)
        if montoEnvio > disponible {
            throw MovimientosParserError.insufficientFunds(
                row: rowIndex,
                crypto: crypto.simbolo,
                requested: montoEnvio,
                available: disponible
            )
        }
        
        return MovimientoEntreCarteras(
            fecha: fecha,
            cantidadCryptoSalida: montoEnvio,
            cantidadCryptoEntrada: montoRecibido,
            carteraOrigen: carteraOrigen,
            carteraDestino: carteraDestino,
            crypto: crypto
        )
    }
}
