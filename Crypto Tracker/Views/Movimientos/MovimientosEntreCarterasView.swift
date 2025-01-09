import SwiftUI
import SwiftData

struct MovimientosEntreCarterasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoEntreCarteras.fecha, order: .reverse) private var movimientos: [MovimientoEntreCarteras]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @State private var showingAddSheet = false
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
                    MovimientoEntreCarterasFormView()
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
                Text(movimiento.crypto.simbolo)
                    .font(.headline)
            }
            
            HStack {
                Text("Cantidad: \(movimiento.cantidadCrypto.formatted()) \(movimiento.crypto.simbolo)")
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "arrow.right")
                    .foregroundStyle(.blue)
                Text("\(movimiento.carteraOrigen.nombre) → \(movimiento.carteraDestino.nombre)")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MovimientoEntreCarterasFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @State private var selectedCrypto: Crypto?
    @State private var selectedCarteraOrigen: Cartera?
    @State private var selectedCarteraDestino: Cartera?
    @State private var fecha = Date()
    @State private var cantidadCrypto: Decimal = 0
    
    var formIsValid: Bool {
        selectedCrypto != nil &&
        selectedCarteraOrigen != nil &&
        selectedCarteraDestino != nil &&
        selectedCarteraOrigen != selectedCarteraDestino &&
        cantidadCrypto > 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Crypto", selection: $selectedCrypto) {
                Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                ForEach(cryptos) { crypto in
                    Text(crypto.nombre).tag(Optional(crypto))
                }
            }
            
            Picker("Cartera Origen", selection: $selectedCarteraOrigen) {
                Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                ForEach(carteras) { cartera in
                    Text(cartera.nombre).tag(Optional(cartera))
                }
            }
            
            Picker("Cartera Destino", selection: $selectedCarteraDestino) {
                Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                ForEach(carteras) { cartera in
                    Text(cartera.nombre).tag(Optional(cartera))
                }
            }
            
            DatePicker("Fecha", selection: $fecha, displayedComponents: [.date, .hourAndMinute])
            
            TextField("Cantidad de Crypto", value: $cantidadCrypto, format: .number)
                .textFieldStyle(.roundedBorder)
            
            if selectedCarteraOrigen == selectedCarteraDestino &&
               selectedCarteraOrigen != nil {
                Text("Las carteras de origen y destino deben ser diferentes")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 300, minHeight: 400)
        .navigationTitle("Nueva Transferencia")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    save()
                }
                .disabled(!formIsValid)
            }
        }
    }
    
    private func save() {
        guard let crypto = selectedCrypto,
              let carteraOrigen = selectedCarteraOrigen,
              let carteraDestino = selectedCarteraDestino,
              carteraOrigen != carteraDestino else { return }
        
        let movimiento = MovimientoEntreCarteras(
            fecha: fecha,
            cantidadCrypto: cantidadCrypto,
            carteraOrigen: carteraOrigen,
            carteraDestino: carteraDestino,
            crypto: crypto
        )
        
        modelContext.insert(movimiento)
        dismiss()
    }
}

#Preview {
    MovimientosEntreCarterasView()
        .withPreviewContainer()
}
