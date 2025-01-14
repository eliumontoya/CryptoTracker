import SwiftUI
import SwiftData

struct CarteraMovimientosView: View {
    let cartera: Cartera
    @Environment(\.dismiss) private var dismiss
    @Query private var cryptos: [Crypto]
    
    @State private var movimientos: [MovimientoDetalle] = []
    @State private var selectedMovimiento: MovimientoDetalle?
    @State private var showingEditSheet = false
    
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
                Text(cartera.nombre)
                    .font(.title2)
                    .bold()
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
        .sheet(item: $selectedMovimiento) { movimiento in
            MovimientoSearchView(
                movimientoDetalle: movimiento            )
        }
    }
    
    private func cargarMovimientos() {
        var movimientosTemp: [MovimientoDetalle] = []
        
        // Procesar movimientos de entrada
        for movimiento in cartera.movimientosIngreso {
            guard let crypto = movimiento.crypto else { continue }
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
        
        // Procesar movimientos de salida
        for movimiento in cartera.movimientosEgreso {
            guard let crypto = movimiento.crypto else { continue }
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
        
        // Procesar transferencias de salida
        for movimiento in cartera.movimientosSalida {
            guard let crypto = movimiento.crypto else { continue }
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
        
        // Procesar transferencias de entrada
        for movimiento in cartera.movimientosEntrada {
            guard let crypto = movimiento.crypto else { continue }
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
        
        // Procesar swaps
        for movimiento in cartera.swaps {
            guard let cryptoOrigen = movimiento.cryptoOrigen,
                  let cryptoDestino = movimiento.cryptoDestino else { continue }
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
        
        // Ordenar movimientos por fecha (más reciente primero)
        movimientos = movimientosTemp.sorted { $0.fecha > $1.fecha }
    }
}
 
