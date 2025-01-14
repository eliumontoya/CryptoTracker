import SwiftUI
import SwiftData

// MARK: - Enums de Modo de Formulario
enum EditMovementMode: Equatable {
    case entrada(MovimientoIngreso)
    case salida(MovimientoEgreso)
    case entreCarteras(MovimientoEntreCarteras)
    case swap(MovimientoSwap)
}

// Tipo auxiliar para hacer el MovimientoDetalle identificable para el sheet
struct IdentifiableMovimientoDetalle: Identifiable {
    let id = UUID()
    let movimientoDetalle: MovimientoDetalle
}

// MARK: - Vista de Edición General
struct EditMovimientoView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: EditMovementMode
    
    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .entrada(let movimiento):
                    MovimientoEntradaFormView(mode: .edit(movimiento))
                case .salida(let movimiento):
                    MovimientoSalidaFormView(mode: .edit(movimiento))
                case .entreCarteras(let movimiento):
                    MovimientoEntreCarterasFormView(mode: .edit(movimiento))
                case .swap(let movimiento):
                    MovimientoSwapFormView(mode: .edit(movimiento))
                }
            }
            .frame(minWidth: 500, minHeight: 700)
        }
    }
}

// MARK: - Vista para buscar el movimiento correcto
struct MovimientoSearchView: View {
    let movimientoDetalle: MovimientoDetalle
    
    @Query private var movimientosIngreso: [MovimientoIngreso]
    @Query private var movimientosEgreso: [MovimientoEgreso]
    @Query private var movimientosEntreCarteras: [MovimientoEntreCarteras]
    @Query private var movimientosSwap: [MovimientoSwap]
    
    var body: some View {
        Group {
            if let mode = findEditMode() {
                EditMovimientoView(mode: mode)
            }
        }
    }
    
    private func findEditMode() -> EditMovementMode? {
        switch movimientoDetalle.tipo {
        case .entrada:
            if let movimiento = movimientosIngreso.first(where: { $0.id == movimientoDetalle.id }) {
                return .entrada(movimiento)
            }
        case .salida:
            if let movimiento = movimientosEgreso.first(where: { $0.id == movimientoDetalle.id }) {
                return .salida(movimiento)
            }
        case .transferencia:
            if let movimiento = movimientosEntreCarteras.first(where: { $0.id == movimientoDetalle.id }) {
                return .entreCarteras(movimiento)
            }
        case .swap:
            if let movimiento = movimientosSwap.first(where: { $0.id == movimientoDetalle.id }) {
                return .swap(movimiento)
            }
        }
        return nil
    }
}

struct MovimientoDetalleRowView: View {
    let movimiento: MovimientoDetalle
    @State private var selectedMovimiento: IdentifiableMovimientoDetalle?
    
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
        .contentShape(Rectangle())
        .onTapGesture {
            selectedMovimiento = IdentifiableMovimientoDetalle(movimientoDetalle: movimiento)
        }
        .sheet(item: $selectedMovimiento) { identifiableMovimiento in
            MovimientoSearchView(movimientoDetalle: identifiableMovimiento.movimientoDetalle)
        }
    }
}
