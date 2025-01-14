import SwiftUI
import SwiftData

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
        
        if case .edit(let movimiento) = mode {
            return cartera.getCryptoDisponible(crypto: crypto, movimientoActual: movimiento.cantidadCryptoSalida)
        } else {
            return cartera.getCryptoDisponible(crypto: crypto)
        }
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
        .navigationTitle(mode == .add ? "Nuevo Movimiento" : "Editar Movimiento")
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
        switch mode {
        case .add:
        let movimiento = MovimientoEntreCarteras(
            fecha: fecha,
            cantidadCryptoSalida: cantidadCryptoSalida,
            cantidadCryptoEntrada: cantidadCryptoEntrada,
            carteraOrigen: carteraOrigen,
            carteraDestino: carteraDestino,
            crypto: crypto
        )
        
        modelContext.insert(movimiento)
            
        case .edit(let movimiento):
            movimiento.fecha = fecha
            movimiento.cantidadCryptoSalida = cantidadCryptoSalida
            movimiento.cantidadCryptoEntrada = cantidadCryptoEntrada
            movimiento.carteraOrigen = carteraOrigen
            movimiento.carteraDestino = carteraDestino
            movimiento.crypto = crypto
        }
        dismiss()
    }
}
