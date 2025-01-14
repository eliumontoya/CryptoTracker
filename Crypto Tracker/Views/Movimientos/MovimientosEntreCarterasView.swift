import SwiftUI
import SwiftData
enum MovimientoEntreCarterasFormMode: Hashable {
    case add
    case edit(MovimientoEntreCarteras)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .add:
            hasher.combine(0)
        case .edit(let movimiento):
            hasher.combine(1)
            hasher.combine(movimiento.id)
        }
    }
    
    static func == (lhs: MovimientoEntreCarterasFormMode, rhs: MovimientoEntreCarterasFormMode) -> Bool {
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
struct MovimientosEntreCarterasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoEntreCarteras.fecha, order: .reverse) private var movimientos: [MovimientoEntreCarteras]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedMovimiento: MovimientoEntreCarteras?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack {
            List {
                ForEach(movimientos) { movimiento in
                    MovimientoEntreCarterasRowView(movimiento: movimiento)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMovimiento = movimiento
                            showingEditSheet = true
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
                    .disabled(cryptos.isEmpty || carteras.count < 2)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    MovimientoEntreCarterasFormView(mode: .add)
                }
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: { selectedMovimiento = nil }) {
                if let movimiento = selectedMovimiento {
                    NavigationStack {
                        MovimientoEntreCarterasFormView(mode: .edit(movimiento))
                    }
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
                    Text("Cantidad Salida: \(movimiento.cantidadCryptoSalida.formatted()) \(crypto.simbolo)")
                    Text("Cantidad Entrada: \(movimiento.cantidadCryptoEntrada.formatted()) \(crypto.simbolo)")
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

#Preview {
    MovimientosEntreCarterasView()
        .withPreviewContainer()
}
