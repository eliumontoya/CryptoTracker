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
    @State private var showingEditSheet = false
    @State private var selectedMovimiento: MovimientoSwap?
    
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoSwapRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                        showingEditSheet = true
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos Swaps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Nuevo Swap", systemImage: "plus")
                }
                .disabled(cryptos.count < 2 || carteras.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MovimientoSwapFormView(mode: .add)
            }
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: { selectedMovimiento = nil }) {
            if let movimiento = selectedMovimiento {
                NavigationStack {
                    MovimientoSwapFormView(mode: .edit(movimiento))
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

struct MovimientoSwapFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mode: MovimientoSwapFormMode
    
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @State private var selectedCryptoOrigen: Crypto?
    @State private var selectedCryptoDestino: Crypto?
    @State private var selectedCartera: Cartera?
    @State private var fecha = Date()
    @State private var cantidadOrigen: Decimal = 0
    @State private var cantidadDestino: Decimal = 0
    @State private var precioUSDOrigen: Decimal = 0
    @State private var precioUSDDestino: Decimal = 0
    
    var valorTotalOrigen: Decimal {
        cantidadOrigen * precioUSDOrigen
    }
    
    var valorTotalDestino: Decimal {
        cantidadDestino * precioUSDDestino
    }
    
    var formIsValid: Bool {
        selectedCryptoOrigen != nil &&
        selectedCryptoDestino != nil &&
        selectedCartera != nil &&
        selectedCryptoOrigen != selectedCryptoDestino &&
        cantidadOrigen > 0 &&
        cantidadDestino > 0 &&
        precioUSDOrigen > 0 &&
        precioUSDDestino > 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Group {
                Text("Cartera *")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.headline)
                Picker("Seleccionar Cartera", selection: $selectedCartera) {
                    Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                    ForEach(carteras) { cartera in
                        Text(cartera.nombre).tag(Optional(cartera))
                    }
                }
            }
            
            DatePicker("Fecha", selection: $fecha, displayedComponents: [.date, .hourAndMinute])
            
            Group {
                Text("Crypto Origen *")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.headline)
                
                Picker("Crypto Origen", selection: $selectedCryptoOrigen) {
                    Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                    ForEach(cryptos) { crypto in
                        Text(crypto.nombre).tag(Optional(crypto))
                    }
                }
                
                TextField("Cantidad Origen", value: $cantidadOrigen, format: .number)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Precio USD", value: $precioUSDOrigen, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
            }
            
            if valorTotalOrigen > 0 {
                HStack {
                    Text("Total USD Origen:")
                    Spacer()
                    Text(valorTotalOrigen.formatted(.currency(code: "USD")))
                        .foregroundStyle(.red)
                }
            }
            
            Group {
                Text("Crypto Destino *")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.headline)
                
                Picker("Crypto Destino", selection: $selectedCryptoDestino) {
                    Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                    ForEach(cryptos) { crypto in
                        Text(crypto.nombre).tag(Optional(crypto))
                    }
                }
                
                TextField("Cantidad Destino", value: $cantidadDestino, format: .number)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Precio USD", value: $precioUSDDestino, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
            }
            
            if valorTotalDestino > 0 {
                HStack {
                    Text("Total USD Destino:")
                    Spacer()
                    Text(valorTotalDestino.formatted(.currency(code: "USD")))
                        .foregroundStyle(.green)
                }
            }
            
            if selectedCryptoOrigen == selectedCryptoDestino &&
               selectedCryptoOrigen != nil {
                Text("Las cryptos de origen y destino deben ser diferentes")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            Spacer()
            
            Text("* Campos obligatorios")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 500)
        .navigationTitle(mode == .add ? "Nuevo Swap" : "Editar Swap")
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
    
    private func loadMovimiento(_ movimiento: MovimientoSwap) {
        selectedCartera = movimiento.cartera
        selectedCryptoOrigen = movimiento.cryptoOrigen
        selectedCryptoDestino = movimiento.cryptoDestino
        fecha = movimiento.fecha
        cantidadOrigen = movimiento.cantidadOrigen
        cantidadDestino = movimiento.cantidadDestino
        precioUSDOrigen = movimiento.precioUSDOrigen
        precioUSDDestino = movimiento.precioUSDDestino
    }
    
    private func save() {
        guard let cryptoOrigen = selectedCryptoOrigen,
              let cryptoDestino = selectedCryptoDestino,
              let cartera = selectedCartera,
              cryptoOrigen != cryptoDestino else { return }
        
        switch mode {
        case .add:
            let movimiento = MovimientoSwap(
                fecha: fecha,
                cantidadOrigen: cantidadOrigen,
                cantidadDestino: cantidadDestino,
                precioUSDOrigen: precioUSDOrigen,
                precioUSDDestino: precioUSDDestino,
                cartera: cartera,
                cryptoOrigen: cryptoOrigen,
                cryptoDestino: cryptoDestino
            )
            modelContext.insert(movimiento)
            
        case .edit(let movimiento):
            movimiento.fecha = fecha
            movimiento.cantidadOrigen = cantidadOrigen
            movimiento.cantidadDestino = cantidadDestino
            movimiento.precioUSDOrigen = precioUSDOrigen
            movimiento.precioUSDDestino = precioUSDDestino
            movimiento.cartera = cartera
            movimiento.cryptoOrigen = cryptoOrigen
            movimiento.cryptoDestino = cryptoDestino
        }
        
        dismiss()
    }
}

#Preview {
    MovimientosSwapsView()
        .withPreviewContainer()
}
