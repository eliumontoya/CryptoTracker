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

struct MovimientoEntreCarterasFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mode: MovimientoEntreCarterasFormMode
    
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @State private var fecha = Date()
    @State private var selectedCrypto: Crypto?
    @State private var selectedCarteraOrigen: Cartera?
    @State private var selectedCarteraDestino: Cartera?
    @State private var cantidadCryptoSalida: Decimal = 0
    @State private var cantidadCryptoEntrada: Decimal = 0
    
    private var cryptoDisponible: Decimal {
        guard let cartera = selectedCarteraOrigen, let crypto = selectedCrypto else { return 0 }
        return cartera.getCryptoDisponible(crypto: crypto)
    }
    
    private var comision: Decimal {
        cantidadCryptoSalida - cantidadCryptoEntrada
    }
    
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Fecha como primer campo
                Group {
                    Text("Fecha *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    DatePicker("", selection: $fecha, displayedComponents: [.date, .hourAndMinute])
                        .frame(maxWidth: .infinity)
                }
                
                // Crypto
                Group {
                    Text("Crypto *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    Picker("Seleccionar Crypto", selection: $selectedCrypto) {
                        Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                        ForEach(cryptos) { crypto in
                            Text(crypto.nombre).tag(Optional(crypto))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .pickerStyle(.menu)
                }
                
                // Cartera Origen
                Group {
                    Text("Cartera Origen *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    Picker("Seleccionar Cartera Origen", selection: $selectedCarteraOrigen) {
                        Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                        ForEach(carteras) { cartera in
                            Text(cartera.nombre).tag(Optional(cartera))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .pickerStyle(.menu)
                }
                
                // Cantidad Crypto Salida
                Group {
                    Text("Cantidad Crypto Salida *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    
                    if let crypto = selectedCrypto {
                        Text("Disponible: \(cryptoDisponible.formatted()) \(crypto.simbolo)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("", value: $cantidadCryptoSalida, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                                .onChange(of: cantidadCryptoSalida) { oldValue, newValue in
                                    if newValue > cryptoDisponible {
                                        cantidadCryptoSalida = cryptoDisponible
                                    }
                                    // Ajustar entrada si es necesario
                                    if cantidadCryptoEntrada > cantidadCryptoSalida {
                                        cantidadCryptoEntrada = cantidadCryptoSalida
                                    }
                                }
                            
                            Button("MAX") {
                                cantidadCryptoSalida = cryptoDisponible
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Cartera Destino
                Group {
                    Text("Cartera Destino *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    Picker("Seleccionar Cartera Destino", selection: $selectedCarteraDestino) {
                        Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                        ForEach(carteras.filter { $0.id != selectedCarteraOrigen?.id }) { cartera in
                            Text(cartera.nombre).tag(Optional(cartera))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .pickerStyle(.menu)
                }
                
                // Cantidad Crypto Entrada
                Group {
                    Text("Cantidad Crypto Entrada *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    
                    if let crypto = selectedCrypto {
                        HStack {
                            TextField("", value: $cantidadCryptoEntrada, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                                .onChange(of: cantidadCryptoEntrada) { oldValue, newValue in
                                    if newValue > cantidadCryptoSalida {
                                        cantidadCryptoEntrada = cantidadCryptoSalida
                                    }
                                }
                            
                            Button("MAX") {
                                cantidadCryptoEntrada = cantidadCryptoSalida
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)
                        }
                        
                        // Mostrar comisión
                        if cantidadCryptoSalida > 0 && cantidadCryptoEntrada > 0 {
                            HStack {
                                Text("Comisión:")
                                Spacer()
                                Text("\(comision.formatted()) \(crypto.simbolo)")
                                    .foregroundStyle(comision > 0 ? .red : .green)
                            }
                            .font(.caption)
                            .padding(.top, 4)
                        }
                    }
                }
                
                Spacer()
                
                // Nota sobre campos obligatorios
                Text("* Campos obligatorios")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity,
               minHeight: 700, idealHeight: 800, maxHeight: .infinity)
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
            if case .edit(let movimiento) = mode {
                loadMovimiento(movimiento)
            }
        }
    }
    
    private var formIsValid: Bool {
        selectedCrypto != nil &&
        selectedCarteraOrigen != nil &&
        selectedCarteraDestino != nil &&
        selectedCarteraOrigen?.id != selectedCarteraDestino?.id &&
        cantidadCryptoSalida > 0 &&
        cantidadCryptoEntrada > 0 &&
        cantidadCryptoEntrada <= cantidadCryptoSalida &&
        cantidadCryptoSalida <= cryptoDisponible
    }
    
    private func loadMovimiento(_ movimiento: MovimientoEntreCarteras) {
        selectedCrypto = movimiento.crypto
        selectedCarteraOrigen = movimiento.carteraOrigen
        selectedCarteraDestino = movimiento.carteraDestino
        fecha = movimiento.fecha
        cantidadCryptoSalida = movimiento.cantidadCryptoSalida
        cantidadCryptoEntrada = movimiento.cantidadCryptoEntrada
    }
    
    private func save() {
        guard let crypto = selectedCrypto,
              let carteraOrigen = selectedCarteraOrigen,
              let carteraDestino = selectedCarteraDestino else { return }
        
        let movimiento = MovimientoEntreCarteras(
            fecha: fecha,
            cantidadCryptoSalida: cantidadCryptoSalida,
            cantidadCryptoEntrada: cantidadCryptoEntrada,
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
