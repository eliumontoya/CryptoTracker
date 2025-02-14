import SwiftUI
import SwiftData

struct MovimientosEntreCarterasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoEntreCarteras.fecha, order: .reverse) private var movimientos: [MovimientoEntreCarteras]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: MovimientoEntreCarteras?
    
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoEntreCarterasRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos Entre Carteras")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Nuevo Movimiento", systemImage: "plus")
                }
            }
        }
        .sheet(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                MovimientoEntreCarterasFormView(
                    viewModel: MovimientoEntreCarterasViewModel(
                        modelContext: modelContext,
                        movimiento: movimiento
                    )
                )
            }
            .frame(minWidth: 500, minHeight: 700)
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MovimientoEntreCarterasFormView(
                    viewModel: MovimientoEntreCarterasViewModel(
                        modelContext: modelContext
                    )
                )
            }
            .frame(minWidth: 500, minHeight: 700)
        }
    }
    
    private func deleteMovimientos(at offsets: IndexSet) {
        Task {
            for index in offsets {
                modelContext.delete(movimientos[index])
            }
            try? modelContext.save()
        }
    }
}

struct MovimientoEntreCarterasRowView: View {
    let movimiento: MovimientoEntreCarteras
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(movimiento.fecha.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                Spacer()
                if let crypto = movimiento.crypto {
                    Text(crypto.simbolo)
                        .font(.headline)
                }
            }
            
            HStack {
                if let crypto = movimiento.crypto {
                    Text("Salida: \(movimiento.cantidadCryptoSalida.formatted()) \(crypto.simbolo)")
                    Text("Entrada: \(movimiento.cantidadCryptoEntrada.formatted()) \(crypto.simbolo)")
                }
            }
            .font(.subheadline)
            
            HStack {
                Image(systemName: "arrow.right")
                    .foregroundStyle(.blue)
                if let carteraOrigen = movimiento.carteraOrigen,
                   let carteraDestino = movimiento.carteraDestino {
                    Text("\(carteraOrigen.nombre) → \(carteraDestino.nombre)")
                        .font(.caption)
                }
            }
            
            // Mostrar comisión si existe
            if let crypto = movimiento.crypto,
               movimiento.cantidadCryptoComision > 0 {
                HStack {
                    Text("Comisión:")
                    Text("\(movimiento.cantidadCryptoComision.formatted()) \(crypto.simbolo)")
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
