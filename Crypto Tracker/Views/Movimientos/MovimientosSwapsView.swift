import SwiftUI
import SwiftData

struct MovimientosSwapsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoSwap.fecha, order: .reverse) private var movimientos: [MovimientoSwap]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: MovimientoSwap?
    
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoSwapRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos de Swaps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Nuevo Movimiento", systemImage: "plus")
                }
            }
        }
        .sheet(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                MovimientoSwapFormView(
                    viewModel: MovimientoSwapViewModel(
                        modelContext: modelContext,
                        movimiento: movimiento
                    )
                )
            }
            .frame(minWidth: 500, minHeight: 700)
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MovimientoSwapFormView(
                    viewModel: MovimientoSwapViewModel(
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

struct MovimientoSwapRowView: View {
    let movimiento: MovimientoSwap
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fecha y cryptos
            HStack {
                Text(movimiento.fecha.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                Spacer()
                if let cryptoOrigen = movimiento.cryptoOrigen,
                   let cryptoDestino = movimiento.cryptoDestino {
                    Text("\(cryptoOrigen.simbolo) → \(cryptoDestino.simbolo)")
                        .font(.headline)
                }
            }
            
            // Cantidades y precios
            VStack(alignment: .leading, spacing: 4) {
                if let cryptoOrigen = movimiento.cryptoOrigen {
                    HStack {
                        Label {
                            Text("\(movimiento.cantidadOrigen.formatted()) \(cryptoOrigen.simbolo)")
                        } icon: {
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.red)
                        }
                        Text("@ \(movimiento.precioUSDOrigen.formatted(.currency(code: "USD")))")
                            .font(.caption)
                    }
                }
                
                if let cryptoDestino = movimiento.cryptoDestino {
                    HStack {
                        Label {
                            Text("\(movimiento.cantidadDestino.formatted()) \(cryptoDestino.simbolo)")
                        } icon: {
                            Image(systemName: "arrow.down.right")
                                .foregroundStyle(.green)
                        }
                        Text("@ \(movimiento.precioUSDDestino.formatted(.currency(code: "USD")))")
                            .font(.caption)
                    }
                }
            }
            .font(.subheadline)
            
            // Cartera
            if let cartera = movimiento.cartera {
                Text("Cartera: \(cartera.nombre)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
