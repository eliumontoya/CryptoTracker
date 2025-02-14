import SwiftUI
import SwiftData

struct MovimientoSwapFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @StateObject var viewModel: MovimientoSwapViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Secciones básicas
                fechaSection
                carteraSection
                
                // Secciones de crypto
                cryptoOrigenSection
                cryptoDestinoSection
                
                // Resumen
                if shouldShowResumen {
                    resumenSection
                }
                
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
        .navigationTitle(viewModel.movimiento == nil ? "Nuevo Swap" : "Editar Swap")
        .toolbar { toolbarContent }
        .alert("Error", isPresented: $viewModel.hasError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var fechaSection: some View {
        Group {
            Text("Fecha *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            DatePicker("", selection: $viewModel.fecha, displayedComponents: [.date, .hourAndMinute])
                .frame(maxWidth: .infinity)
        }
    }
    
    private var carteraSection: some View {
        Group {
            Text("Cartera *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            Picker("Seleccionar Cartera", selection: $viewModel.selectedCartera) {
                Text("Seleccionar Cartera").tag(Optional<Cartera>.none)
                ForEach(carteras) { cartera in
                    Text(cartera.nombre).tag(Optional(cartera))
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(.menu)
        }
    }
    
    private var cryptoOrigenSection: some View {
        CryptoOrigenSectionView(
            viewModel: viewModel,
            cryptos: cryptos
        )
    }
    
    private var cryptoDestinoSection: some View {
        CryptoDestinoSectionView(
            viewModel: viewModel,
            cryptos: cryptos
        )
    }
    
    private var shouldShowResumen: Bool {
        guard let _ = viewModel.selectedCryptoOrigen,
              let _ = viewModel.selectedCryptoDestino else { return false }
        return viewModel.cantidadOrigen > 0 &&
               viewModel.cantidadDestino > 0 &&
               viewModel.precioUSDOrigen > 0 &&
               viewModel.precioUSDDestino > 0
    }
    
    private var resumenSection: some View {
        ResumenSwapSectionView(viewModel: viewModel)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
}

// MARK: - Subviews
struct CryptoOrigenSectionView: View {
    @ObservedObject var viewModel: MovimientoSwapViewModel
    let cryptos: [Crypto]
    
    var body: some View {
        Group {
            Text("Crypto Origen *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            
            Picker("Seleccionar Crypto Origen", selection: $viewModel.selectedCryptoOrigen) {
                Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                ForEach(cryptos) { crypto in
                    Text(crypto.nombre).tag(Optional(crypto))
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(.menu)
            
            if let crypto = viewModel.selectedCryptoOrigen {
                cryptoOrigenDetails(crypto)
            }
        }
    }
    
    private func cryptoOrigenDetails(_ crypto: Crypto) -> some View {
        Group {
            Text("Disponible: \(viewModel.cryptoDisponible.formatted()) \(crypto.simbolo)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Cantidad Origen *")
                    .font(.subheadline)
                HStack {
                    TextField("", value: $viewModel.cantidadOrigen, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: viewModel.cantidadOrigen) { _, _ in
                            viewModel.adjustCantidadOrigen()
                        }
                    
                    Button("MAX") {
                        viewModel.setMaxCantidadOrigen()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Precio USD Origen *")
                    .font(.subheadline)
                TextField("", value: $viewModel.precioUSDOrigen, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }
            
            if viewModel.cantidadOrigen > 0 && viewModel.precioUSDOrigen > 0 {
                Text("Total USD Origen: \(viewModel.valorTotalOrigen.formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct CryptoDestinoSectionView: View {
    @ObservedObject var viewModel: MovimientoSwapViewModel
    let cryptos: [Crypto]
    
    var body: some View {
        Group {
            Text("Crypto Destino *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            
            Picker("Seleccionar Crypto Destino", selection: $viewModel.selectedCryptoDestino) {
                Text("Seleccionar Crypto").tag(Optional<Crypto>.none)
                ForEach(cryptos.filter { $0.id != viewModel.selectedCryptoOrigen?.id }) { crypto in
                    Text(crypto.nombre).tag(Optional(crypto))
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(.menu)
            
            if let crypto = viewModel.selectedCryptoDestino {
                cryptoDestinoDetails(crypto)
            }
        }
    }
    
    private func cryptoDestinoDetails(_ crypto: Crypto) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cantidad Destino *")
                    .font(.subheadline)
                TextField("", value: $viewModel.cantidadDestino, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Precio USD Destino *")
                    .font(.subheadline)
                TextField("", value: $viewModel.precioUSDDestino, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }
            
            if viewModel.cantidadDestino > 0 && viewModel.precioUSDDestino > 0 {
                Text("Total USD Destino: \(viewModel.valorTotalDestino.formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct ResumenSwapSectionView: View {
    @ObservedObject var viewModel: MovimientoSwapViewModel
    
    var body: some View {
        Group {
            Divider()
            
            Text("Resumen de Swap")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let cryptoOrigen = viewModel.selectedCryptoOrigen,
               let cryptoDestino = viewModel.selectedCryptoDestino {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Entrega:")
                            .foregroundStyle(.red)
                        Text("\(viewModel.cantidadOrigen.formatted()) \(cryptoOrigen.simbolo)")
                        Text("(\(viewModel.valorTotalOrigen.formatted(.currency(code: "USD"))))")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Recibe:")
                            .foregroundStyle(.green)
                        Text("\(viewModel.cantidadDestino.formatted()) \(cryptoDestino.simbolo)")
                        Text("(\(viewModel.valorTotalDestino.formatted(.currency(code: "USD"))))")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
