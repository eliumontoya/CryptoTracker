import SwiftUI
import SwiftData

struct MovimientoEntradaFormView: View {
    let preselectedCartera: Cartera? // Nueva propiedad

    init(mode: MovimientoEntradaFormMode, preselectedCartera: Cartera? = nil) {
            self.mode = mode
            self.preselectedCartera = preselectedCartera
            _selectedCartera = State(initialValue: preselectedCartera)
        }

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
                            .onChange(of: cantidadCrypto) { oldValue, newValue in
                                onCantidadCryptoChange()
                            }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Precio Crypto al Adquirirlo *")
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
                    Toggle("FIAT Invertido en Crypto", isOn: $usaFiatAlterno)
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
        .navigationTitle(mode == .add ? "Nueva Entrada" : "Editar Entrada")
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
