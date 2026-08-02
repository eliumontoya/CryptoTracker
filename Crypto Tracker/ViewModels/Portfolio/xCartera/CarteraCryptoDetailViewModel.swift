import Foundation
import SwiftData
import Combine

@MainActor
final class CarteraCryptoDetailViewModel: ObservableObject {
    @Published var movimientos: [MovimientoDetalle] = []
    @Published var selectedMovimientoDetalle: MovimientoDetalle?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let crypto: Crypto
    private let cartera: Cartera

    init(crypto: Crypto, cartera: Cartera) {
        self.crypto = crypto
        self.cartera = cartera
    }

    var title: String {
        "\(crypto.nombre) (\(crypto.simbolo))"
    }

    var subtitle: String {
        "Cartera: \(cartera.nombre)"
    }


    func cargarMovimientos() {
        isLoading = true
        var movimientosTemp: [MovimientoDetalle] = []

        cartera.movimientos
            .filter { movimiento in
                movimiento.crypto?.id == crypto.id ||
                movimiento.cryptoOrigen?.id == crypto.id ||
                movimiento.cryptoDestino?.id == crypto.id
            }
            .forEach { movimiento in
                switch movimiento.tipo {
                case .entrada:
                    movimientosTemp.append(MovimientoDetalle(
                        id: movimiento.id,
                        fecha: movimiento.fecha,
                        tipo: .entrada,
                        carteraOrigen: nil,
                        carteraDestino: cartera.nombre,
                        cantidadOrigen: movimiento.cantidadCrypto,
                        cantidadDestino: movimiento.cantidadCrypto,
                        cryptoOrigen: crypto.simbolo,
                        cryptoDestino: crypto.simbolo,
                        valorUSD: movimiento.valorTotalUSD
                    ))

                case .salida:
                    movimientosTemp.append(MovimientoDetalle(
                        id: movimiento.id,
                        fecha: movimiento.fecha,
                        tipo: .salida,
                        carteraOrigen: cartera.nombre,
                        carteraDestino: nil,
                        cantidadOrigen: movimiento.cantidadCrypto,
                        cantidadDestino: movimiento.cantidadCrypto,
                        cryptoOrigen: crypto.simbolo,
                        cryptoDestino: crypto.simbolo,
                        valorUSD: movimiento.valorTotalUSD
                    ))

                case .transferenciaSalida:
                    movimientosTemp.append(MovimientoDetalle(
                        id: movimiento.id,
                        fecha: movimiento.fecha,
                        tipo: .transferencia,
                        carteraOrigen: cartera.nombre,
                        carteraDestino: movimiento.carteraDestino?.nombre ?? "Desconocida",
                        cantidadOrigen: movimiento.cantidadCryptoSalida,
                        cantidadDestino: movimiento.cantidadCryptoEntrada,
                        cryptoOrigen: crypto.simbolo,
                        cryptoDestino: crypto.simbolo,
                        valorUSD: nil
                    ))

                case .transferenciaEntrada:
                    movimientosTemp.append(MovimientoDetalle(
                        id: movimiento.id,
                        fecha: movimiento.fecha,
                        tipo: .transferencia,
                        carteraOrigen: movimiento.carteraOrigen?.nombre ?? "Desconocida",
                        carteraDestino: cartera.nombre,
                        cantidadOrigen: movimiento.cantidadCryptoSalida,
                        cantidadDestino: movimiento.cantidadCryptoEntrada,
                        cryptoOrigen: crypto.simbolo,
                        cryptoDestino: crypto.simbolo,
                        valorUSD: nil
                    ))

                case .swapSalida:
                    movimientosTemp.append(MovimientoDetalle(
                        id: movimiento.id,
                        fecha: movimiento.fecha,
                        tipo: .swap,
                        carteraOrigen: cartera.nombre,
                        carteraDestino: cartera.nombre,
                        cantidadOrigen: movimiento.cantidadOrigen,
                        cantidadDestino: movimiento.cantidadDestino,
                        cryptoOrigen: movimiento.cryptoOrigen?.simbolo ?? "Desconocida",
                        cryptoDestino: movimiento.cryptoDestino?.simbolo ?? "Desconocida",
                        valorUSD: movimiento.cantidadOrigen * movimiento.precioUSDOrigen
                    ))

                case .swapEntrada, .ajuste, .comision:
                    // La pierna .swapSalida ya representa el swap completo.
                    break
                }
            }

        // Ordenar movimientos por fecha (más reciente primero)
        movimientos = movimientosTemp.sorted { $0.fecha > $1.fecha }
        isLoading = false
    }
}
