import SwiftUI
import SwiftData

struct MovimientoSalidaFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @StateObject var viewModel: MovimientoSalidaViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Fecha
                dateSection
                
                // Campos principales
                mainFieldsSection
                
                // Campos USD
                usdFieldsSection
                
                // FIAT Alterno
                if viewModel.usaFiatAlterno {
                    fiatAlternoSection
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
        .navigationTitle(viewModel.movimiento == nil ? "Nueva Salida" : "Editar Salida")
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
    
    private var mainFieldsSection: some View {
        Group {
            // Crypto
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
            
            // Cartera
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
    
    private var usdFieldsSection: some View {
        Group {
            Text("Datos en USD *")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Cryptos Vendidos *")
                    .font(.subheadline)
                TextField("", value: $viewModel.cantidadCrypto, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .onChange(of: viewModel.cantidadCrypto) { _, _ in
                        viewModel.onCantidadCryptoChange()
                    }
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Precio Crypto al Vender *")
                    .font(.subheadline)
                TextField("", value: $viewModel.precioUSD, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.usaFiatAlterno)
            }
            
            Text("Total USD: \(viewModel.valorTotalUSD.formatted(.currency(code: "USD")))")
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var fiatAlternoSection: some View {
        Group {
            Toggle("FIAT Recibido en Venta", isOn: $viewModel.usaFiatAlterno)
                .font(.headline)
                .frame(maxWidth: .infinity)
            
            Picker("FIAT Alterno", selection: $viewModel.selectedFiatAlterno) {
                Text("Seleccionar FIAT").tag(Optional<FIAT>.none)
                ForEach(fiats.filter { $0.simbolo != "USD" }) { fiat in
                    Text(fiat.nombre).tag(Optional(fiat))
                }
            }
            .frame(maxWidth: .infinity)
            .pickerStyle(.menu)
            
            if let fiat = viewModel.selectedFiatAlterno {
                Text("Tasa de cambio: 1 USD = \(fiat.precioUSD.formatted()) \(fiat.simbolo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total en \(fiat.simbolo) *")
                        .font(.subheadline)
                    TextField("", value: $viewModel.valorTotalFiatAlterno, format: .currency(code: fiat.simbolo))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: viewModel.valorTotalFiatAlterno) { _, _ in
                            viewModel.calcularPrecioUSD()
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
