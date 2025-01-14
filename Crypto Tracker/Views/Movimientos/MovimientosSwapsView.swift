import SwiftUI
import SwiftData

enum MovimientoSwapFormMode: Hashable {
    case add
    case edit(MovimientoSwap)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .add:
            hasher.combine(0)
        case .edit(let movimiento):
            hasher.combine(1)
            hasher.combine(movimiento.id)
        }
    }
    
    static func == (lhs: MovimientoSwapFormMode, rhs: MovimientoSwapFormMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add):
            return true
        case (.edit(let m1), .edit(let m2)):
            return m1.id == m2.id
        default:
            return false
        }
    }
}


struct MovimientosSwapsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoSwap.fecha, order: .reverse) private var movimientos: [MovimientoSwap]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false  // Agregado
    @State private var selectedMovimiento: MovimientoSwap?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack {
            List {
                ForEach(movimientos) { movimiento in
                    MovimientoSwapRowView(movimiento: movimiento)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMovimiento = movimiento
                            showingEditSheet = true  // Cambiado
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
                    .disabled(cryptos.isEmpty || carteras.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    MovimientoSwapFormView(mode: .add)
                }
                .frame(minWidth: 500, minHeight: 700)
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: { selectedMovimiento = nil }) {
                if let movimiento = selectedMovimiento {
                    NavigationStack {
                        MovimientoSwapFormView(mode: .edit(movimiento))
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
            }
        }
    }
    private func deleteMovimientos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(movimientos[index])
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

#Preview {
    MovimientosSwapsView()
        .withPreviewContainer()
}
