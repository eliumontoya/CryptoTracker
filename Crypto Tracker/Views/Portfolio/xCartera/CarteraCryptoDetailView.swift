import SwiftUI
import SwiftData

struct CarteraCryptoDetailView: View {
    let crypto: Crypto
    let cartera: Cartera
    @Environment(\.dismiss) private var dismiss
    
    @State private var movimientos: [MovimientoDetalle] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Volver")
                    }
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("\(crypto.nombre) (\(crypto.simbolo))")
                        .font(.title2)
                        .bold()
                    Text("Cartera: \(cartera.nombre)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom)
            
            // Lista de movimientos
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(movimientos) { movimiento in
                        MovimientoDetalleRowView(movimiento: movimiento)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            cargarMovimientos()
        }
    }
    
    private func cargarMovimientos() {
        var movimientosTemp: [MovimientoDetalle] = []
        
        // Movimientos de entrada
        for movimiento in cartera.movimientosIngreso where movimiento.crypto?.id == crypto.id {
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
        for movimiento in cartera.movimientosEgreso where movimiento.crypto?.id == crypto.id {
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
        for movimiento in cartera.movimientosSalida where movimiento.crypto?.id == crypto.id {
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
        for movimiento in cartera.movimientosEntrada where movimiento.crypto?.id == crypto.id {
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
        for movimiento in cartera.swaps where movimiento.cryptoOrigen?.id == crypto.id {
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
        for movimiento in cartera.swaps where movimiento.cryptoDestino?.id == crypto.id {
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
    }
}
