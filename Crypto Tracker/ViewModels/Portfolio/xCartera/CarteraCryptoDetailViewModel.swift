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
        
        // Movimientos de entrada
        cartera.movimientosIngreso
            .filter { $0.crypto?.id == crypto.id }
            .forEach { movimiento in
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
            }
        
        // Movimientos de salida
        cartera.movimientosEgreso
            .filter { $0.crypto?.id == crypto.id }
            .forEach { movimiento in
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
            }
        
        // Transferencias entre carteras (como origen)
        cartera.movimientosSalida
            .filter { $0.crypto?.id == crypto.id }
            .forEach { movimiento in
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
            }
        
        // Transferencias entre carteras (como destino)
        cartera.movimientosEntrada
            .filter { $0.crypto?.id == crypto.id }
            .forEach { movimiento in
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
            }
        
        // Swaps (como origen)
        cartera.swaps
            .filter { $0.cryptoOrigen?.id == crypto.id }
            .forEach { movimiento in
                movimientosTemp.append(MovimientoDetalle(
                    id: movimiento.id,
                    fecha: movimiento.fecha,
                    tipo: .swap,
                    carteraOrigen: cartera.nombre,
                    carteraDestino: cartera.nombre,
                    cantidadOrigen: movimiento.cantidadOrigen,
                    cantidadDestino: movimiento.cantidadDestino,
                    cryptoOrigen: crypto.simbolo,
                    cryptoDestino: movimiento.cryptoDestino?.simbolo ?? "Desconocida",
                    valorUSD: movimiento.cantidadOrigen * movimiento.precioUSDOrigen
                ))
            }
        
        // Swaps (como destino)
        cartera.swaps
            .filter { $0.cryptoDestino?.id == crypto.id }
            .forEach { movimiento in
                movimientosTemp.append(MovimientoDetalle(
                    id: movimiento.id,
                    fecha: movimiento.fecha,
                    tipo: .swap,
                    carteraOrigen: cartera.nombre,
                    carteraDestino: cartera.nombre,
                    cantidadOrigen: movimiento.cantidadOrigen,
                    cantidadDestino: movimiento.cantidadDestino,
                    cryptoOrigen: movimiento.cryptoOrigen?.simbolo ?? "Desconocida",
                    cryptoDestino: crypto.simbolo,
                    valorUSD: movimiento.cantidadDestino * movimiento.precioUSDDestino
                ))
            }
        
        // Ordenar movimientos por fecha (más reciente primero)
        movimientos = movimientosTemp.sorted { $0.fecha > $1.fecha }
        isLoading = false
    }
}
