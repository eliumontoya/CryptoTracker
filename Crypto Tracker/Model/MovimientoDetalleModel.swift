import Foundation

// MARK: - Tipos de Movimiento
enum TipoMovimientoDetalle {
    case entrada
    case salida
    case transferencia
    case swap
}

// MARK: - Modelo de Movimiento Detalle
struct MovimientoDetalle: Identifiable {
    let id: UUID
    let fecha: Date
    let tipo: TipoMovimientoDetalle
    let carteraOrigen: String?
    let carteraDestino: String?
    let cantidadOrigen: Decimal
    let cantidadDestino: Decimal
    let cryptoOrigen: String
    let cryptoDestino: String
    let valorUSD: Decimal?
}
