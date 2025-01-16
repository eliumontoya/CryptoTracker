import SwiftUI
import SwiftData

enum MovimientoSalidaFormMode: Hashable {
    case add
    case edit(MovimientoEgreso)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .add:
            hasher.combine(0)
        case .edit(let movimiento):
            hasher.combine(1)
            hasher.combine(movimiento.id)
        }
    }
    
    static func == (lhs: MovimientoSalidaFormMode, rhs: MovimientoSalidaFormMode) -> Bool {
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


struct MovimientosSalidaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoEgreso.fecha, order: .reverse) private var movimientos: [MovimientoEgreso]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedMovimiento: MovimientoEgreso?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoSalidaRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                        showingEditSheet = true
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos de Salida")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Nuevo Movimiento", systemImage: "plus")
                }
                .disabled(cryptos.isEmpty || carteras.isEmpty)
            }
        }
 
        
        .sheet(item: $selectedMovimiento) { movimiento in
                    NavigationStack {
                        MovimientoSalidaFormView(
                            mode: movimiento.id == nil ? .add : .edit(movimiento)
                        )
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
        .sheet(isPresented: $showingAddSheet) {
                    NavigationStack {
                        MovimientoSalidaFormView(mode: .add)
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
    }
    
   

    private func deleteMovimientos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(movimientos[index])
        }
    }
}

struct MovimientoSalidaRowView: View {
    let movimiento: MovimientoEgreso
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primera línea: Fecha y Crypto
            HStack {
                Text(movimiento.fecha.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                Spacer()
                if let crypto = movimiento.crypto {
                    Text(crypto.simbolo)
                        .font(.headline)
                }
            }
            
            // Segunda línea: Cantidad y Precio USD
            HStack {
                if let crypto = movimiento.crypto {
                    Text("Cantidad: \(movimiento.cantidadCrypto.formatted()) \(crypto.simbolo)")
                }
                Spacer()
                Text("Precio USD: \(movimiento.precioUSD.formatted(.currency(code: "USD")))")
            }
            .font(.subheadline)
            
            // Tercera línea: Cartera y totales
            HStack {
                if let cartera = movimiento.cartera {
                    Text("Cartera: \(cartera.nombre)")
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Total USD: \(movimiento.valorTotalUSD.formatted(.currency(code: "USD")))")
                    if movimiento.usaFiatAlterno,
                       let fiat = movimiento.fiatAlterno,
                       let valorFiat = movimiento.valorTotalFiatAlterno {
                        Text("Total \(fiat.simbolo): \(valorFiat.formatted(.currency(code: fiat.simbolo)))")
                            .foregroundStyle(.green)
                    }
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MovimientosSalidaView()
        .withPreviewContainer()
}
