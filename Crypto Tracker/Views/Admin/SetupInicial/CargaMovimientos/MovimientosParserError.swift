import Foundation

enum MovimientosParserError: LocalizedError {
    case invalidDate(row: Int, value: String)
    case invalidNumber(row: Int, field: String, value: String)
    case carteraNotFound(row: Int, nombre: String)
    case cryptoNotFound(row: Int, simbolo: String)
    case fiatNotFound(row: Int, simbolo: String)
    case invalidFormat(String)
    case missingData(row: Int, field: String)
    case insufficientFunds(row: Int, crypto: String, requested: Decimal, available: Decimal)
    case sameWallet(row: Int)
       case invalidReceivedAmount(row: Int, sent: Decimal, received: Decimal)
    
    var errorDescription: String? {
        switch self {
        case .invalidDate(let row, let value):
            return "Error en fila \(row): La fecha '\(value)' no tiene el formato correcto (debe ser DD/MM/YYYY)"
        case .invalidNumber(let row, let field, let value):
            return "Error en fila \(row): El valor '\(value)' para '\(field)' no es un número válido"
        case .carteraNotFound(let row, let nombre):
            return """
                Error en fila \(row): No se encontró la cartera con ID '\(nombre)' en los catálogos.
                Asegúrese de usar el símbolo/ID de la cartera (ejemplo: BIN para Binance) y no el nombre completo.
                """
        case .cryptoNotFound(let row, let simbolo):
            return "Error en fila \(row): No se encontró la crypto '\(simbolo)' en los catálogos"
        case .fiatNotFound(let row, let simbolo):
            return "Error en fila \(row): No se encontró el FIAT '\(simbolo)' en los catálogos"
        case .invalidFormat(let message):
            return "Error de formato: \(message)"
        case .missingData(let row, let field):
            let ayuda = field.contains("Cartera") ?
                "Debe especificar el ID/Símbolo de la cartera (ejemplo: BIN para Binance)" :
                "Este campo es obligatorio"
            return "Error en fila \(row): Falta el valor para el campo '\(field)'. \(ayuda)"
        case .insufficientFunds(let row, let crypto, let requested, let available):
            return """
                Error en fila \(row): Fondos insuficientes para \(crypto).
                Solicitado: \(requested)
                Disponible: \(available)
                """
        case .sameWallet(let row):
                    return "Error en fila \(row): La cartera origen y destino no pueden ser la misma"
            case .invalidReceivedAmount(let row, let sent, let received):
                    return """
                        Error en fila \(row): El monto recibido (\(received)) no puede ser mayor 
                        al monto enviado (\(sent))
                        """
        }
    }
}
