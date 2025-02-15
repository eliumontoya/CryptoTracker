import Foundation
import SwiftData
import Combine

@MainActor
final class CarteraMovimientosViewModel: ObservableObject {
    @Published var movimientos: [MovimientoDetalle] = []
    @Published var selectedMovimientoDetalle: MovimientoDetalle?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cartera: Cartera
    private let modelContext: ModelContext
    
    init(cartera: Cartera, modelContext: ModelContext) {
        self.cartera = cartera
        self.modelContext = modelContext
    }
    
    var carteraNombre: String {
        cartera.nombre
    }
    
    func cargarMovimientos() {
        isLoading = true
        
        do {
            var movimientosTemp: [MovimientoDetalle] = []
            
            // Procesar movimientos de entrada
            cartera.movimientosIngreso.forEach { movimiento in
                if let crypto = movimiento.crypto {
                    movimientosTemp.append(crearMovimientoDetalle(
                        id: movimiento.id,
                        fecha: movimiento.fecha,
                        tipo: .entrada,
                        crypto: crypto,
                        cantidadOrigen: movimiento.cantidadCrypto,
                        cantidadDestino: movimiento.cantidadCrypto,
                        valorUSD: movimiento.valorTotalUSD,
                        carteraDestino: cartera.nombre
                    ))
                }
            }
            
            // Procesar movimientos de salida
            cartera.movimientosEgreso.forEach { movimiento in
                if let crypto = movimiento.crypto {
                    movimientosTemp.append(crearMovimientoDetalle(
                        id: movimiento.id,
                        fecha: movimiento.fecha,
                        tipo: .salida,
                        crypto: crypto,
                        cantidadOrigen: movimiento.cantidadCrypto,
                        cantidadDestino: movimiento.cantidadCrypto,
                        valorUSD: movimiento.valorTotalUSD,
                        carteraOrigen: cartera.nombre
                    ))
                }
            }
            
            // Procesar transferencias
            procesarTransferencias(movimientosTemp: &movimientosTemp)
            
            // Procesar swaps
            procesarSwaps(movimientosTemp: &movimientosTemp)
            
            // Ordenar movimientos por fecha (más reciente primero)
            movimientos = movimientosTemp.sorted { $0.fecha > $1.fecha }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func procesarTransferencias(movimientosTemp: inout [MovimientoDetalle]) {
        // Salida
        cartera.movimientosSalida.forEach { movimiento in
            if let crypto = movimiento.crypto {
                movimientosTemp.append(crearMovimientoDetalle(
                    id: movimiento.id,
                    fecha: movimiento.fecha,
                    tipo: .transferencia,
                    crypto: crypto,
                    cantidadOrigen: movimiento.cantidadCryptoSalida,
                    cantidadDestino: movimiento.cantidadCryptoEntrada,
                    carteraOrigen: cartera.nombre,
                    carteraDestino: movimiento.carteraDestino?.nombre ?? "Desconocida"
                ))
            }
        }
        
        // Entrada
        cartera.movimientosEntrada.forEach { movimiento in
            if let crypto = movimiento.crypto {
                movimientosTemp.append(crearMovimientoDetalle(
                    id: movimiento.id,
                    fecha: movimiento.fecha,
                    tipo: .transferencia,
                    crypto: crypto,
                    cantidadOrigen: movimiento.cantidadCryptoSalida,
                    cantidadDestino: movimiento.cantidadCryptoEntrada,
                    carteraOrigen: movimiento.carteraOrigen?.nombre ?? "Desconocida",
                    carteraDestino: cartera.nombre
                ))
            }
        }
    }
    
    private func procesarSwaps(movimientosTemp: inout [MovimientoDetalle]) {
        cartera.swaps.forEach { movimiento in
            if let cryptoOrigen = movimiento.cryptoOrigen,
               let cryptoDestino = movimiento.cryptoDestino {
                movimientosTemp.append(MovimientoDetalle(
                    id: movimiento.id,
                    fecha: movimiento.fecha,
                    tipo: .swap,
                    carteraOrigen: cartera.nombre,
                    carteraDestino: cartera.nombre,
                    cantidadOrigen: movimiento.cantidadOrigen,
                    cantidadDestino: movimiento.cantidadDestino,
                    cryptoOrigen: cryptoOrigen.simbolo,
                    cryptoDestino: cryptoDestino.simbolo,
                    valorUSD: movimiento.cantidadOrigen * movimiento.precioUSDOrigen
                ))
            }
        }
    }
    
    private func crearMovimientoDetalle(
        id: UUID,
        fecha: Date,
        tipo: TipoMovimientoDetalle,
        crypto: Crypto,
        cantidadOrigen: Decimal,
        cantidadDestino: Decimal,
        valorUSD: Decimal? = nil,
        carteraOrigen: String? = nil,
        carteraDestino: String? = nil
    ) -> MovimientoDetalle {
        MovimientoDetalle(
            id: id,
            fecha: fecha,
            tipo: tipo,
            carteraOrigen: carteraOrigen,
            carteraDestino: carteraDestino,
            cantidadOrigen: cantidadOrigen,
            cantidadDestino: cantidadDestino,
            cryptoOrigen: crypto.simbolo,
            cryptoDestino: crypto.simbolo,
            valorUSD: valorUSD
        )
    }
}
