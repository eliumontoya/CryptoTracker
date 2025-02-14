import SwiftUI
import SwiftData

struct MovimientoEntreCarterasFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @StateObject var viewModel: MovimientoEntreCarterasViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Fecha
                dateSection
                
                // Crypto
                cryptoSection
                
                // Cartera Origen
                carteraOrigenSection
                
                // Cantidad Crypto Salida
                cantidadSalidaSection
                
                // Cartera Destino
                carteraDestinoSection
                
                // Cantidad Crypto Entrada
                cantidadEntradaSection
                
                Spacer(minLength: 20)
                
                // Nota campos obligatorios
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
        .navigationTitle(viewModel.movimiento == nil ? "Nueva Transferencia" : "Editar Transferencia")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            
            if viewModel.movimiento != nil {
                ToolbarItem(placement: .automatic) {
                    Button(role: .destructive) {
                        Task {
                            try? await viewModel.delete()
                            dismiss()
                        }
                    } label: {
                        Text("Eliminar")
                    }
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    Task {
                        do {
                            try await viewModel.save()
                            dismiss()
                        } catch {
                            // Error handling is managed by ViewModel
                        }
                    }
                }
                .disabled(!viewModel.formIsValid)
            }
        }
        .alert("Error", isPresented: $viewModel.hasError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var dateSection: some View {
        Group {
            Text("Fecha *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            DatePicker("", selection: $viewModel.fecha, displayedComponents: [.date, .hourAndMinute])
                .frame(maxWidth: .infinity)
        }
    }
    
    private var cryptoSection: some View {
        Group {
            Text("Crypto *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            Picker("Seleccionar Crypto", selection: $viewModel.selectedCrypto) {
                Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                ForEach(cryptos) { crypto in
                    Text(crypto.nombre).tag(Optional(crypto))
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(.menu)
        }
    }
    
    private var carteraOrigenSection: some View {
        Group {
            Text("Cartera Origen *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            Picker("Seleccionar Cartera Origen", selection: $viewModel.selectedCarteraOrigen) {
                Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                ForEach(carteras) { cartera in
                    Text(cartera.nombre).tag(Optional(cartera))
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(.menu)
        }
    }
    
    private var cantidadSalidaSection: some View {
        Group {
            Text("Cantidad Crypto Salida *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            
            if let crypto = viewModel.selectedCrypto {
                Text("Disponible: \(viewModel.cryptoDisponible.formatted()) \(crypto.simbolo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("", value: $viewModel.cantidadCryptoSalida, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: viewModel.cantidadCryptoSalida) { _, _ in
                            viewModel.adjustCantidades()
                        }
                    
                    Button("MAX") {
                        viewModel.setMaxCantidadSalida()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var carteraDestinoSection: some View {
        Group {
            Text("Cartera Destino *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            Picker("Seleccionar Cartera Destino", selection: $viewModel.selectedCarteraDestino) {
                Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                ForEach(carteras.filter { $0.id != viewModel.selectedCarteraOrigen?.id }) { cartera in
                    Text(cartera.nombre).tag(Optional(cartera))
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(.menu)
        }
    }
    
    private var cantidadEntradaSection: some View {
        Group {
            Text("Cantidad Crypto Entrada *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            
            if let crypto = viewModel.selectedCrypto {
                HStack {
                    TextField("", value: $viewModel.cantidadCryptoEntrada, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: viewModel.cantidadCryptoEntrada) { _, _ in
                            viewModel.adjustCantidades()
                        }
                    
                    Button("MAX") {
                        viewModel.setMaxCantidadEntrada()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
                
                // Mostrar comisión
                if viewModel.cantidadCryptoSalida > 0 && viewModel.cantidadCryptoEntrada > 0 {
                    HStack {
                        Text("Comisión:")
                        Spacer()
                        Text("\(viewModel.comision.formatted()) \(crypto.simbolo)")
                            .foregroundStyle(viewModel.comision > 0 ? .red : .green)
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            }
        }
    }
}
