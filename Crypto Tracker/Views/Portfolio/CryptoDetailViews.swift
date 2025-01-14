import SwiftUI
import SwiftData

// MARK: - Vista principal de detalle de Crypto
struct CryptoDetailView: View {
    let crypto: Crypto
    @Environment(\.dismiss) private var dismiss
    @Query private var carteras: [Cartera]
    
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
                
                Text("\(crypto.nombre) (\(crypto.simbolo))")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom)
            
            // Lista de movimientos
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(movimientos) { movimiento in
                        MovimientoCryptoDetalleRowView(movimiento: movimiento)
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
        
        // Procesar todas las carteras
        for cartera in carteras {
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
        }
        
        // Ordenar movimientos por fecha (más reciente primero)
        movimientos = movimientosTemp.sorted { $0.fecha > $1.fecha }
    }
}

// MARK: - Modelos de Datos
enum TipoMovimientoDetalle {
    case entrada
    case salida
    case transferencia
    case swap
}

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

// MARK: - Vista de Fila de Movimiento
struct MovimientoCryptoDetalleRowView: View {
    let movimiento: MovimientoDetalle
    
    private var iconoMovimiento: String {
        switch movimiento.tipo {
        case .entrada:
            return "arrow.down.circle.fill"
        case .salida:
            return "arrow.up.circle.fill"
        case .transferencia:
            return "arrow.left.arrow.right.circle.fill"
        case .swap:
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }
    
    private var colorMovimiento: Color {
        switch movimiento.tipo {
        case .entrada:
            return .green
        case .salida:
            return .red
        case .transferencia:
            return .blue
        case .swap:
            return .orange
        }
    }
    
    private var tituloMovimiento: String {
        switch movimiento.tipo {
        case .entrada:
            return "Entrada"
        case .salida:
            return "Salida"
        case .transferencia:
            return "Transferencia"
        case .swap:
            return "Swap"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primera línea: Fecha y tipo de movimiento
            HStack {
                Image(systemName: iconoMovimiento)
                    .foregroundStyle(colorMovimiento)
                Text(tituloMovimiento)
                    .foregroundStyle(colorMovimiento)
                Spacer()
                Text(movimiento.fecha.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Segunda línea: Cantidades y cryptos
            VStack(alignment: .leading, spacing: 4) {
                switch movimiento.tipo {
                case .entrada:
                    Text("Recibido: \(movimiento.cantidadDestino.formatted()) \(movimiento.cryptoDestino)")
                case .salida:
                    Text("Enviado: \(movimiento.cantidadOrigen.formatted()) \(movimiento.cryptoOrigen)")
                case .transferencia:
                    Text("Enviado: \(movimiento.cantidadOrigen.formatted()) \(movimiento.cryptoOrigen)")
                    Text("Recibido: \(movimiento.cantidadDestino.formatted()) \(movimiento.cryptoDestino)")
                case .swap:
                    Text("Enviado: \(movimiento.cantidadOrigen.formatted()) \(movimiento.cryptoOrigen)")
                    Text("Recibido: \(movimiento.cantidadDestino.formatted()) \(movimiento.cryptoDestino)")
                }
            }
            .font(.subheadline)
            
            // Tercera línea: Carteras involucradas
            HStack {
                switch movimiento.tipo {
                case .entrada:
                    Text("A cartera: \(movimiento.carteraDestino ?? "Desconocida")")
                case .salida:
                    Text("Desde cartera: \(movimiento.carteraOrigen ?? "Desconocida")")
                case .transferencia:
                    Text("\(movimiento.carteraOrigen ?? "Desconocida") → \(movimiento.carteraDestino ?? "Desconocida")")
                case .swap:
                    Text("En cartera: \(movimiento.carteraOrigen ?? "Desconocida")")
                }
                
                Spacer()
                
                if let valorUSD = movimiento.valorUSD {
                    Text(valorUSD.formatted(.currency(code: "USD")))
                        .foregroundStyle(colorMovimiento)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}
