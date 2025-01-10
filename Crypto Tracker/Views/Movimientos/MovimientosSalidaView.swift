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
// En MovimientoSalidaFormView, agregar:
private func getCryptoDisponible(cartera: Cartera?, crypto: Crypto?) -> Decimal {
    guard let cartera = cartera, let crypto = crypto else { return 0 }
    
    // Calcular ingresos totales
    let ingresos = cartera.movimientosIngreso
        .filter { $0.crypto?.id == crypto.id }
        .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
    
    // Calcular egresos totales
    let egresos = cartera.movimientosEgreso
        .filter { $0.crypto?.id == crypto.id }
        .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
    
    // Calcular transferencias entrantes
    let transferenciasEntrada = cartera.movimientosEntrada
        .filter { $0.crypto?.id == crypto.id }
        .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
    
    // Calcular transferencias salientes
    let transferenciasSalida = cartera.movimientosSalida
        .filter { $0.crypto?.id == crypto.id }
        .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
    
    // Calcular swaps entrantes
    let swapsEntrada = cartera.swaps
        .filter { $0.cryptoDestino?.id == crypto.id }
        .reduce(Decimal(0)) { $0 + $1.cantidadDestino }
    
    // Calcular swaps salientes
    let swapsSalida = cartera.swaps
        .filter { $0.cryptoOrigen?.id == crypto.id }
        .reduce(Decimal(0)) { $0 + $1.cantidadOrigen }
    
    // Calcular balance total
    return ingresos + transferenciasEntrada + swapsEntrada -
           (egresos + transferenciasSalida + swapsSalida)
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
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MovimientoSalidaFormView(mode: .add)
            }
            .frame(minWidth: 500, minHeight: 700)
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: { selectedMovimiento = nil }) {
            if let movimiento = selectedMovimiento {
                NavigationStack {
                    MovimientoSalidaFormView(mode: .edit(movimiento))
                }
                .frame(minWidth: 500, minHeight: 700)
            }
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

struct MovimientoSalidaFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mode: MovimientoSalidaFormMode
    
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var selectedCrypto: Crypto?
    @State private var selectedCartera: Cartera?
    @State private var fecha = Date()
    
    // Campos USD (obligatorios)
    @State private var cantidadCrypto: Decimal = 0
    @State private var precioUSD: Decimal = 0
    @State private var valorTotalUSD: Decimal = 0
    
    // Campos FIAT Alterno (opcionales)
    @State private var usaFiatAlterno = false
    @State private var selectedFiatAlterno: FIAT?
    @State private var valorTotalFiatAlterno: Decimal = 0
    
    // Valores calculados
    private var precioFiatAlterno: Decimal {
        guard cantidadCrypto > 0 else { return 0 }
        return valorTotalFiatAlterno / cantidadCrypto
    }
    
    private func calcularPrecioUSD() {
        if usaFiatAlterno, let fiat = selectedFiatAlterno {
            valorTotalUSD = valorTotalFiatAlterno * (1 / fiat.precioUSD)
            if cantidadCrypto > 0 {
                precioUSD = valorTotalUSD / cantidadCrypto
            }
        }
    }
    
    private func onCantidadCryptoChange() {
        if usaFiatAlterno {
            if cantidadCrypto > 0 {
                calcularPrecioUSD()
            }
        } else {
            valorTotalUSD = cantidadCrypto * precioUSD
        }
    }
    
    var formIsValid: Bool {
        guard let cartera = selectedCartera,
              let crypto = selectedCrypto else { return false }
        
        let disponible = getCryptoDisponible(cartera: cartera, crypto: crypto)
        
        return cantidadCrypto > 0 &&
               cantidadCrypto <= disponible &&
               precioUSD > 0 &&
               (!usaFiatAlterno || (selectedFiatAlterno != nil && valorTotalFiatAlterno > 0))
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
                
                // Campos principales
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
                    .frame(maxWidth: .infinity)
                    .pickerStyle(.menu)
                }
                
                // Campos USD
                Group {
                    Text("Datos en USD *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    
                    // En el body del formulario, donde está el campo de cantidad:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cryptos Vendidos *")
                            .font(.subheadline)
                        
                        if let cartera = selectedCartera, let crypto = selectedCrypto {
                            let disponible = getCryptoDisponible(cartera: cartera, crypto: crypto)
                            Text("Disponible en cartera: \(disponible.formatted()) \(crypto.simbolo)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("", value: $cantidadCrypto, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                    .onChange(of: cantidadCrypto) { oldValue, newValue in
                                        // Validar que no exceda el disponible
                                        if newValue > disponible {
                                            cantidadCrypto = disponible
                                        }
                                        onCantidadCryptoChange()
                                    }
                                
                                Button("MAX") {
                                    cantidadCrypto = disponible
                                    onCantidadCryptoChange()
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.blue)
                            }
                            
                            if cantidadCrypto > disponible {
                                Text("No hay suficientes \(crypto.simbolo) en la cartera")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Precio Crypto al Venderlo *")
                            .font(.subheadline)
                        TextField("", value: $precioUSD, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .disabled(usaFiatAlterno)
                            .onChange(of: precioUSD) { oldValue, newValue in
                                if !usaFiatAlterno {
                                    valorTotalUSD = cantidadCrypto * newValue
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("Total USD: \(valorTotalUSD.formatted(.currency(code: "USD")))")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                // FIAT Alterno
                Group {
                    Toggle("FIAT Recibido por Crypto", isOn: $usaFiatAlterno)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .onChange(of: usaFiatAlterno) { oldValue, newValue in
                            if newValue {
                                // Al activar FIAT, recalcular valorTotalFiatAlterno desde USD
                                if let fiat = selectedFiatAlterno {
                                    valorTotalFiatAlterno = valorTotalUSD * fiat.precioUSD
                                }
                            } else {
                                // Al desactivar FIAT, mantener los valores USD
                                selectedFiatAlterno = nil
                                valorTotalFiatAlterno = 0
                            }
                        }
                    
                    if usaFiatAlterno {
                        Picker("FIAT Alterno", selection: $selectedFiatAlterno) {
                            Text("Seleccionar FIAT").tag(Optional<FIAT>.none)
                            ForEach(fiats.filter { $0.simbolo != "USD" }) { fiat in
                                Text(fiat.nombre).tag(Optional(fiat))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .pickerStyle(.menu)
                        
                        if let fiat = selectedFiatAlterno {
                            Text("Tasa de cambio: 1 USD = \(fiat.precioUSD.formatted()) \(fiat.simbolo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total en \(fiat.simbolo) *")
                                    .font(.subheadline)
                                TextField("", value: $valorTotalFiatAlterno, format: .currency(code: fiat.simbolo))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                    .onChange(of: valorTotalFiatAlterno) { oldValue, newValue in
                                        calcularPrecioUSD()
                                    }
                            }
                            .frame(maxWidth: .infinity)
                            
                            if valorTotalFiatAlterno > 0 && cantidadCrypto > 0 {
                                Text("Precio por crypto: \(precioFiatAlterno.formatted(.currency(code: fiat.simbolo)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 20)
                
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
        .navigationTitle(mode == .add ? "Nuevo Movimiento" : "Editar Movimiento")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            
            if case .edit = mode {
                ToolbarItem(placement: .automatic) {
                    Button(role: .destructive) {
                        if case .edit(let movimiento) = mode {
                            modelContext.delete(movimiento)
                        }
                        dismiss()
                    } label: {
                        Text("Eliminar")
                            .foregroundStyle(.red)
                    }
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
    
    private func loadMovimiento(_ movimiento: MovimientoEgreso) {
        selectedCrypto = movimiento.crypto
        selectedCartera = movimiento.cartera
        fecha = movimiento.fecha
        cantidadCrypto = movimiento.cantidadCrypto
        precioUSD = movimiento.precioUSD
        valorTotalUSD = movimiento.valorTotalUSD
        usaFiatAlterno = movimiento.usaFiatAlterno
        selectedFiatAlterno = movimiento.fiatAlterno
        valorTotalFiatAlterno = movimiento.valorTotalFiatAlterno ?? 0
    }
    
    private func save() {
        guard let crypto = selectedCrypto,
              let cartera = selectedCartera else { return }
        
        switch mode {
        case .add:
            let movimiento = MovimientoEgreso(
                fecha: fecha,
                cantidadCrypto: cantidadCrypto,
                precioUSD: precioUSD,
                usaFiatAlterno: usaFiatAlterno,
                precioFiatAlterno: usaFiatAlterno ? precioFiatAlterno : nil,
                valorTotalFiatAlterno: usaFiatAlterno ? valorTotalFiatAlterno : nil,
                cartera: cartera,
                crypto: crypto,
                fiatAlterno: usaFiatAlterno ? selectedFiatAlterno : nil
            )
            modelContext.insert(movimiento)
            
        case .edit(let movimiento):
            movimiento.fecha = fecha
            movimiento.cantidadCrypto = cantidadCrypto
            movimiento.precioUSD = precioUSD
            movimiento.valorTotalUSD = valorTotalUSD
            movimiento.usaFiatAlterno = usaFiatAlterno
            movimiento.precioFiatAlterno = usaFiatAlterno ? precioFiatAlterno : nil
            movimiento.valorTotalFiatAlterno = usaFiatAlterno ? valorTotalFiatAlterno : nil
            movimiento.cartera = cartera
            movimiento.crypto = crypto
            movimiento.fiatAlterno = usaFiatAlterno ? selectedFiatAlterno : nil
        }
        
        dismiss()
    }
}

#Preview {
    MovimientosSalidaView()
        .withPreviewContainer()
}
