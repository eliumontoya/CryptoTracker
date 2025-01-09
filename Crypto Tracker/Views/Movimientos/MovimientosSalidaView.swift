import SwiftUI
import SwiftData

struct MovimientosSalidaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoEgreso.fecha, order: .reverse) private var movimientos: [MovimientoEgreso]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: MovimientoEgreso?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack {
            List {
                ForEach(movimientos) { movimiento in
                    MovimientoEgresoRowView(movimiento: movimiento)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMovimiento = movimiento
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
                    .disabled(cryptos.isEmpty || carteras.isEmpty || fiats.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    MovimientoEgresoFormView()
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

struct MovimientoEgresoRowView: View {
    let movimiento: MovimientoEgreso
    
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
                Text("Cantidad: \(movimiento.criptoSalido.formatted()) \(movimiento.crypto.simbolo)")
                Spacer()
                Text("Precio: \(movimiento.precioCryptoSalido.formatted(.currency(code: "USD")))")
            }
            .font(.subheadline)
            
            HStack {
                Text("Cartera: \(movimiento.cartera.nombre)")
                Spacer()
                Text("Total: \(movimiento.valorSalido.formatted(.currency(code: movimiento.fiatReferencia.simbolo)))")
                    .foregroundStyle(.red)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct MovimientoEgresoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var selectedCrypto: Crypto?
    @State private var selectedCartera: Cartera?
    @State private var selectedFiat: FIAT?
    @State private var fecha = Date()
    @State private var cantidadCrypto: Decimal = 0
    @State private var precioCrypto: Decimal = 0
    
    var valorTotal: Decimal {
        cantidadCrypto * precioCrypto
    }
    
    var formIsValid: Bool {
        selectedCrypto != nil &&
        selectedCartera != nil &&
        selectedFiat != nil &&
        cantidadCrypto > 0 &&
        precioCrypto > 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Crypto", selection: $selectedCrypto) {
                Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                ForEach(cryptos) { crypto in
                    Text(crypto.nombre).tag(Optional(crypto))
                }
            }
            
            Picker("Cartera", selection: $selectedCartera) {
                Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                ForEach(carteras) { cartera in
                    Text(cartera.nombre).tag(Optional(cartera))
                }
            }
            
            Picker("Moneda", selection: $selectedFiat) {
                Text("Seleccionar Moneda").tag(Optional<FIAT>.none)
                ForEach(fiats) { fiat in
                    Text(fiat.nombre).tag(Optional(fiat))
                }
            }
            
            DatePicker("Fecha", selection: $fecha, displayedComponents: [.date, .hourAndMinute])
            
            TextField("Cantidad de Crypto", value: $cantidadCrypto, format: .number)
                .textFieldStyle(.roundedBorder)
            
            TextField("Precio por Crypto", value: $precioCrypto, format: .currency(code: selectedFiat?.simbolo ?? "USD"))
                .textFieldStyle(.roundedBorder)
            
            if valorTotal > 0 {
                HStack {
                    Text("Valor Total:")
                    Spacer()
                    Text(valorTotal.formatted(.currency(code: selectedFiat?.simbolo ?? "USD")))
                        .foregroundStyle(.red)
                }
                .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 300, minHeight: 400)
        .navigationTitle("Nuevo Movimiento de Salida")
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
        .onAppear {
            if let firstFiat = fiats.first {
                selectedFiat = firstFiat
            }
        }
    }
    
    private func save() {
        guard let crypto = selectedCrypto,
              let cartera = selectedCartera,
              let fiat = selectedFiat else { return }
        
        let movimiento = MovimientoEgreso(
            fecha: fecha,
            criptoSalido: cantidadCrypto,
            valorSalido: valorTotal,
            precioCryptoSalido: precioCrypto,
            cartera: cartera,
            crypto: crypto,
            fiatReferencia: fiat
        )
        
        modelContext.insert(movimiento)
        dismiss()
    }
}

#Preview {
    MovimientosSalidaView()
        .withPreviewContainer()
}
