// MovimientoComponents.swift
import SwiftUI
import SwiftData

// MARK: - Vista de Detalles de Movimiento
struct MovimientoDetalleRowView: View {
    let movimiento: MovimientoDetalle
    let onTap: () -> Void
    
    private var iconoMovimiento: String {
        movimiento.tipo.icon
    }
    
    private var colorMovimiento: Color {
        switch movimiento.tipo {
        case .entrada: return .green
        case .salida: return .red
        case .transferencia: return .blue
        case .swap: return .orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            contentView
            footerView
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: iconoMovimiento)
                .foregroundStyle(colorMovimiento)
            Text(movimiento.tipo.title)
                .foregroundStyle(colorMovimiento)
            Spacer()
            Text(movimiento.fecha.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch movimiento.tipo {
            case .entrada:
                Text("Recibido: \(movimiento.cantidadDestino.formatted()) \(movimiento.cryptoDestino)")
            case .salida:
                Text("Enviado: \(movimiento.cantidadOrigen.formatted()) \(movimiento.cryptoOrigen)")
            case .transferencia, .swap:
                Text("Enviado: \(movimiento.cantidadOrigen.formatted()) \(movimiento.cryptoOrigen)")
                Text("Recibido: \(movimiento.cantidadDestino.formatted()) \(movimiento.cryptoDestino)")
            }
        }
        .font(.subheadline)
    }
    
    private var footerView: some View {
        HStack {
            carterasText
            Spacer()
            if let valorUSD = movimiento.valorUSD {
                Text(valorUSD.formatted(.currency(code: "USD")))
                    .foregroundStyle(colorMovimiento)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    private var carterasText: some View {
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
    }
}

// MARK: - Componentes Compartidos
struct MovimientoLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Cargando...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MovimientoErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text(message)
                .multilineTextAlignment(.center)
            
            Button("Reintentar") {
                onRetry()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct MovimientoEmptyView: View {
    let message: String
    
    var body: some View {
        VStack {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}
