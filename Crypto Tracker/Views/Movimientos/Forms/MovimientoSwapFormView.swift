import SwiftUI
import SwiftData


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
    private var cryptoDisponible: Decimal {

        guard let cryptoOrigen = selectedCryptoOrigen  else { return 0 }

        
        if case .edit(let movimiento) = mode {
            return selectedCartera?.getCryptoDisponible(crypto: cryptoOrigen, movimientoActual: movimiento.cantidadOrigen) ?? 0
        } else {
            return selectedCartera?.getCryptoDisponible(crypto: cryptoOrigen) ?? 0
        }
    }
    
    var formIsValid: Bool {

        return selectedCryptoDestino != nil &&
               cantidadOrigen > 0 &&
               cantidadOrigen <= cryptoDisponible &&
               cantidadDestino > 0 &&
               precioUSDOrigen > 0 &&
               precioUSDDestino > 0 &&
               selectedCryptoOrigen != selectedCryptoDestino
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Fecha como primer campo (A1)
                Group {
                    Text("Fecha *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    DatePicker("", selection: $fecha, displayedComponents: [.date, .hourAndMinute])
                        .frame(maxWidth: .infinity)
                }
                
                // Cartera
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
                
                // Crypto Origen y cantidad
                Group {
                    Text("Crypto Origen *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    Picker("Seleccionar Crypto Origen", selection: $selectedCryptoOrigen) {
                        Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                        ForEach(cryptos) { crypto in
                            Text(crypto.nombre).tag(Optional(crypto))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .pickerStyle(.menu)
                    
                    // Mostrar disponible y validación
                    if let crypto = selectedCryptoOrigen {
                        Text("Disponible: \(cryptoDisponible.formatted()) \(crypto.simbolo)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cantidad Origen *")
                                .font(.subheadline)
                            HStack {
                                TextField("", value: $cantidadOrigen, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                    .onChange(of: cantidadOrigen) { oldValue, newValue in
                                        if newValue > cryptoDisponible {
                                            cantidadOrigen = cryptoDisponible
                                        }
                                    }
                                
                                Button("MAX") {
                                    cantidadOrigen = cryptoDisponible
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Precio USD Origen *")
                                .font(.subheadline)
                            TextField("", value: $precioUSDOrigen, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        
                        if cantidadOrigen > 0 && precioUSDOrigen > 0 {
                            Text("Total USD Origen: \((cantidadOrigen * precioUSDOrigen).formatted(.currency(code: "USD")))")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Crypto Destino y cantidad
                Group {
                    Text("Crypto Destino *")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.headline)
                    Picker("Seleccionar Crypto Destino", selection: $selectedCryptoDestino) {
                        Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                        ForEach(cryptos.filter { $0.id != selectedCryptoOrigen?.id }) { crypto in
                            Text(crypto.nombre).tag(Optional(crypto))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .pickerStyle(.menu)
                    
                    if let crypto = selectedCryptoDestino {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cantidad Destino *")
                                .font(.subheadline)
                            TextField("", value: $cantidadDestino, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Precio USD Destino *")
                                .font(.subheadline)
                            TextField("", value: $precioUSDDestino, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        
                        if cantidadDestino > 0 && precioUSDDestino > 0 {
                            Text("Total USD Destino: \((cantidadDestino * precioUSDDestino).formatted(.currency(code: "USD")))")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // Resumen de la operación
                if let cryptoOrigen = selectedCryptoOrigen,
                   let cryptoDestino = selectedCryptoDestino,
                   cantidadOrigen > 0,
                   cantidadDestino > 0,
                   precioUSDOrigen > 0,
                   precioUSDDestino > 0 {
                    
                    Group {
                        Divider()
                        
                        Text("Resumen de Swap")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Entrega:")
                                    .foregroundStyle(.red)
                                Text("\(cantidadOrigen.formatted()) \(cryptoOrigen.simbolo)")
                                Text("(\((cantidadOrigen * precioUSDOrigen).formatted(.currency(code: "USD"))))")
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Recibe:")
                                    .foregroundStyle(.green)
                                Text("\(cantidadDestino.formatted()) \(cryptoDestino.simbolo)")
                                Text("(\((cantidadDestino * precioUSDDestino).formatted(.currency(code: "USD"))))")
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 8)
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
        .navigationTitle(mode == .add ? "Nuevo Swap" : "Editar Swap")
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
