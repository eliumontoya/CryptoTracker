import SwiftUI
import SwiftData

enum MovimientoEntradaFormMode: Hashable {
    case add
    case edit(MovimientoIngreso)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .add:
            hasher.combine(0)
        case .edit(let movimiento):
            hasher.combine(1)
            hasher.combine(movimiento.id)
        }
    }
    
    static func == (lhs: MovimientoEntradaFormMode, rhs: MovimientoEntradaFormMode) -> Bool {
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

struct MovimientosEntradaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoIngreso.fecha, order: .reverse) private var movimientos: [MovimientoIngreso]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedMovimiento: MovimientoIngreso?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoEntradaRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                        showingEditSheet = true
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos de Entrada")
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
                MovimientoEntradaFormView(mode: .add)
            }
            .frame(minWidth: 500, minHeight: 700)
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: { selectedMovimiento = nil }) {
            if let movimiento = selectedMovimiento {
                NavigationStack {
                    MovimientoEntradaFormView(mode: .edit(movimiento))
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

struct MovimientoEntradaRowView: View {
    let movimiento: MovimientoIngreso
    
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

struct MovimientoEntradaFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mode: MovimientoEntradaFormMode
    
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var selectedCrypto: Crypto?
    @State private var selectedCartera: Cartera?
    @State private var fecha = Date()
    
    // Campos USD (obligatorios)
    @State private var cantidadCrypto: Decimal = 0
    @State private var precioUSD: Decimal = 0
    
    // Campos FIAT Alterno (opcionales)
    @State private var usaFiatAlterno = false
    @State private var selectedFiatAlterno: FIAT?
    @State private var precioFiatAlterno: Decimal = 0
    
    // Valores calculados
    var valorTotalUSD: Decimal {
        cantidadCrypto * precioUSD
    }
    
    var valorTotalFiatAlterno: Decimal {
        if let fiat = selectedFiatAlterno {
            return cantidadCrypto * precioFiatAlterno
        }
        return 0
    }
    
    var formIsValid: Bool {
        selectedCrypto != nil &&
        selectedCartera != nil &&
        cantidadCrypto > 0 &&
        precioUSD > 0 &&
        (!usaFiatAlterno || (selectedFiatAlterno != nil && precioFiatAlterno > 0))
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cryptos Adquiridos *")
                            .font(.subheadline)
                        TextField("", value: $cantidadCrypto, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Precio Crypto al Adquirirlo *")
                            .font(.subheadline)
                        TextField("", value: $precioUSD, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if valorTotalUSD > 0 {
                        HStack {
                            Text("Total USD:")
                            Spacer()
                            Text(valorTotalUSD.formatted(.currency(code: "USD")))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // FIAT Alterno
                Group {
                    Toggle("FIAT Invertido en Crypto", isOn: $usaFiatAlterno)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    
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
                            
                            TextField("Precio en \(fiat.simbolo)", value: $precioFiatAlterno, format: .currency(code: fiat.simbolo))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                                .onChange(of: precioFiatAlterno) { oldValue, newValue in
                                    precioUSD = newValue / fiat.precioUSD
                                }
                            
                            if valorTotalFiatAlterno > 0 {
                                HStack {
                                    Text("Total \(fiat.simbolo):")
                                    Spacer()
                                    Text(valorTotalFiatAlterno.formatted(.currency(code: fiat.simbolo)))
                                        .foregroundStyle(.green)
                                }
                                .frame(maxWidth: .infinity)
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
    
    private func loadMovimiento(_ movimiento: MovimientoIngreso) {
        selectedCrypto = movimiento.crypto
        selectedCartera = movimiento.cartera
        fecha = movimiento.fecha
        cantidadCrypto = movimiento.cantidadCrypto
        precioUSD = movimiento.precioUSD
        usaFiatAlterno = movimiento.usaFiatAlterno
        selectedFiatAlterno = movimiento.fiatAlterno
        precioFiatAlterno = movimiento.precioFiatAlterno ?? 0
    }
    
    private func save() {
            guard let crypto = selectedCrypto,
                  let cartera = selectedCartera else { return }
            
            switch mode {
            case .add:
                let movimiento = MovimientoIngreso(
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
        MovimientosEntradaView()
            .withPreviewContainer()
    }
