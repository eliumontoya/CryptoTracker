import Foundation
import SwiftData

struct MovimientoSalidaHeaders {
    static let fecha = "Fecha"
    static let crypto = "Cripto"
    static let cartera = "ID_Cartera"
    static let cantidad = "Crypto Salido"
    static let precioUSD = "Precio USD Venta"
    static let valorTotalUSD = "USD Total Salido"
    static let fiatRecibido = "FIAT Recibido"
    static let fiatSimbolo = "FIAT_Simbolo"
    
    static let required = [
        fecha, crypto, cartera, cantidad, precioUSD
    ]
}

class MovimientoSalidaParser {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    static func parse(
        worksheet: ExcelWorksheet,
        carteras: [Cartera],
        cryptos: [Crypto],
        fiats: [FIAT],
        skipFundCheck: Bool = false
    ) throws -> [Movimiento] {
        print("🔍 Validando encabezados del archivo de salida...")
        try worksheet.validateHeaders(MovimientoSalidaHeaders.required)
        
        let headers = Dictionary(uniqueKeysWithValues: worksheet.headerRow.enumerated().map { ($1, $0) })
        var movimientos: [Movimiento] = []
        
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
                    fiats: fiats,
                    skipFundCheck: skipFundCheck
                )
                movimientos.append(movimiento)
                print("✅ Fila \(currentRow) procesada correctamente")
            } catch {
                print("❌ Error en fila \(currentRow): \(error.localizedDescription)")
                throw error
            }
        }
        
        print("✅ Procesamiento completado. Total movimientos de salida: \(movimientos.count)")
        return movimientos
    }
    
    private static func parseRow(
        row: [String],
        rowIndex: Int,
        headers: [String: Int],
        carteras: [Cartera],
        cryptos: [Crypto],
        fiats: [FIAT],
        skipFundCheck: Bool = false
    ) throws -> Movimiento {
        // Fecha
        guard let fechaStr = row[safe: headers[MovimientoSalidaHeaders.fecha] ?? -1]?.trimmingCharacters(in: .whitespaces),
              !fechaStr.isEmpty else {
            throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSalidaHeaders.fecha)
        }
        
        guard let fecha = dateFormatter.date(from: fechaStr) else {
            throw MovimientosParserError.invalidDate(row: rowIndex, value: fechaStr)
        }
                
                // Crypto
                guard let cryptoSimbolo = row[safe: headers[MovimientoSalidaHeaders.crypto] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !cryptoSimbolo.isEmpty else {
                    throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSalidaHeaders.crypto)
                }
                
                let cryptoId = cryptoSimbolo.uppercased()
                guard let crypto = cryptos.first(where: { $0.simbolo.uppercased() == cryptoId }) else {
                    throw MovimientosParserError.cryptoNotFound(row: rowIndex, simbolo: cryptoId)
                }
                
                // Cartera
                guard let carteraNombre = row[safe: headers[MovimientoSalidaHeaders.cartera] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !carteraNombre.isEmpty else {
                    throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSalidaHeaders.cartera)
                }
                
                let carteraId = carteraNombre.uppercased()
                guard let cartera = carteras.first(where: { $0.simbolo.uppercased() == carteraId }) else {
                    throw MovimientosParserError.carteraNotFound(row: rowIndex, nombre: carteraId)
                }
                
                // Cantidad
                guard let cantidadStr = row[safe: headers[MovimientoSalidaHeaders.cantidad] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !cantidadStr.isEmpty else {
                    throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSalidaHeaders.cantidad)
                }
                
                guard let cantidadCrypto = Decimal(string: cantidadStr) else {
                    throw MovimientosParserError.invalidNumber(
                        row: rowIndex,
                        field: MovimientoSalidaHeaders.cantidad,
                        value: cantidadStr
                    )
                }
                
                // Verificar disponibilidad (omitir durante carga inicial)
                if !skipFundCheck {
                    let disponible = cartera.getCryptoDisponible(crypto: crypto)
                    if cantidadCrypto > disponible {
                        throw MovimientosParserError.insufficientFunds(
                            row: rowIndex,
                            crypto: crypto.simbolo,
                            requested: cantidadCrypto,
                            available: disponible
                        )
                    }
                }
                
                // Precio USD
                guard let precioUSDStr = row[safe: headers[MovimientoSalidaHeaders.precioUSD] ?? -1]?.trimmingCharacters(in: .whitespaces),
                      !precioUSDStr.isEmpty else {
                    throw MovimientosParserError.missingData(row: rowIndex, field: MovimientoSalidaHeaders.precioUSD)
                }
                
                guard let precioUSD = Decimal(string: precioUSDStr) else {
                    throw MovimientosParserError.invalidNumber(
                        row: rowIndex,
                        field: MovimientoSalidaHeaders.precioUSD,
                        value: precioUSDStr
                    )
                }

                let valorCalculadoUSD = cantidadCrypto * precioUSD
                let valorTotalUSD = try parseValorTotalUSD(
                    row: row,
                    headers: headers,
                    rowIndex: rowIndex,
                    valorCalculado: valorCalculadoUSD
                )
                
                // FIAT opcional
                let (usaFiatAlterno, fiatAlterno, valorTotalFiatAlterno) = try parseFiatOpcional(
                    row: row,
                    headers: headers,
                    rowIndex: rowIndex,
                    fiats: fiats,
                    cantidadCrypto: cantidadCrypto
                )
                
                let movimiento = Movimiento.salida(
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
                movimiento.valorTotalUSD = valorTotalUSD
                return movimiento
            }

            private static func parseValorTotalUSD(
                row: [String],
                headers: [String: Int],
                rowIndex: Int,
                valorCalculado: Decimal
            ) throws -> Decimal {
                guard let columnIndex = headers[MovimientoSalidaHeaders.valorTotalUSD] else {
                    return valorCalculado
                }
                let rawValue = row[safe: columnIndex]?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !rawValue.isEmpty else { return valorCalculado }
                guard let valorProvisto = Decimal(string: rawValue) else {
                    throw MovimientosParserError.invalidNumber(
                        row: rowIndex,
                        field: MovimientoSalidaHeaders.valorTotalUSD,
                        value: rawValue
                    )
                }

                let diferencia = abs(valorProvisto - valorCalculado)
                let tolerancia = max(Decimal(string: "0.01")!, abs(valorCalculado) * Decimal(string: "0.0001")!)
                guard diferencia <= tolerancia else {
                    throw MovimientosParserError.invalidFormat(
                        "Fila \(rowIndex): '\(MovimientoSalidaHeaders.valorTotalUSD)' (\(valorProvisto)) no coincide con cantidad × precio (\(valorCalculado))"
                    )
                }
                return valorProvisto
            }
            
            private static func parseFiatOpcional(
                row: [String],
                headers: [String: Int],
                rowIndex: Int,
                fiats: [FIAT],
                cantidadCrypto: Decimal
            ) throws -> (usa: Bool, fiat: FIAT?, valor: Decimal?) {
                if let valorFiatStr = row[safe: headers[MovimientoSalidaHeaders.fiatRecibido] ?? -1]?.trimmingCharacters(in: .whitespaces),
                   let simboloFiat = row[safe: headers[MovimientoSalidaHeaders.fiatSimbolo] ?? -1]?.trimmingCharacters(in: .whitespaces),
                   !valorFiatStr.isEmpty,
                   !simboloFiat.isEmpty {
                    
                    guard let valorFiat = Decimal(string: valorFiatStr) else {
                        throw MovimientosParserError.invalidNumber(
                            row: rowIndex,
                            field: MovimientoSalidaHeaders.fiatRecibido,
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
