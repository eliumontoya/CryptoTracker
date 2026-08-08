import SwiftUI
import SwiftData

struct AdminCryptosView: View {
    @StateObject private var viewModel: AdminCryptosViewModel
    
    init(viewModel: AdminCryptosViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(viewModel.cryptos) { crypto in
                    CryptoRowView(crypto: crypto, viewModel: viewModel)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedCrypto = crypto
                            viewModel.showEditForm(for: crypto)
                        }
                }
                .onDelete { offsets in
                    let candidates = offsets.map { viewModel.cryptos[$0] }
                    viewModel.requestDeletion(of: candidates)
                }
            }
            .navigationTitle("Cryptos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showAddForm() }) {
                        Label("Agregar Crypto", systemImage: "plus")
                    }
                    .accessibilityIdentifier("admin-cryptos-add")
                }
            }
            .sheet(item: $viewModel.formState) { formState in
                NavigationStack {
                    switch formState {
                    case .add:
                        CryptoFormView(viewModel: viewModel)
                    case .edit(let crypto):
                        CryptoFormView(viewModel: viewModel, crypto: crypto)
                    }
                }
            }
            .alert(viewModel.deleteAlertTitle, isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {
                    viewModel.cancelDeletion()
                }
                if viewModel.deleteRequiresConfirmation {
                    Button("Eliminar", role: .destructive) {
                        viewModel.confirmDeletion()
                    }
                }
            } message: {
                Text(viewModel.deleteAlertMessage)
            }
        }
        .accessibilityIdentifier("admin-cryptos-view")
    }
}

struct CryptoRowView: View {
    let crypto: Crypto
    let viewModel: AdminCryptosViewModel
    @State private var showingHistory = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(crypto.nombre)
                    .font(.headline)
                Text("(\(crypto.simbolo))")
                    .foregroundColor(.secondary)
                Spacer()
                let calculos = viewModel.getCalculosCrypto(crypto)
                Text(Format.usd(calculos.precio))
                    .font(.subheadline)
            }
            
            HStack {
                let calculos = viewModel.getCalculosCrypto(crypto)
                Text("Última actualización: \(Format.date(calculos.ultimaActualizacion))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                CryptoHistoryButton(crypto: crypto, showingHistory: $showingHistory)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CryptoFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdminCryptosViewModel
    
    let crypto: Crypto?
    
    @State private var nombre: String = ""
    @State private var simbolo: String = ""
    @State private var precio: Decimal = 0.0
    @State private var coingeckoId: String = ""

    init(viewModel: AdminCryptosViewModel, crypto: Crypto? = nil) {
        self.viewModel = viewModel
        self.crypto = crypto
        _nombre = State(initialValue: crypto?.nombre ?? "")
        _simbolo = State(initialValue: crypto?.simbolo ?? "")
        _precio = State(initialValue: crypto?.precio ?? 0.0)
        _coingeckoId = State(initialValue: crypto?.coingeckoId ?? "")
    }
    
    var title: String {
        crypto == nil ? "Nueva Crypto" : "Editar Crypto"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Nombre", text: $nombre)
                .textFieldStyle(.roundedBorder)
            TextField("Símbolo", text: $simbolo)
                .textFieldStyle(.roundedBorder)
            TextField("Precio", value: $precio, format: .currency(code: "USD"))
                .textFieldStyle(.roundedBorder)

            TextField("CoinGecko ID", text: $coingeckoId)
                .textFieldStyle(.roundedBorder)

            Spacer()
        }
        .padding()
        .adaptiveSheetFrame(minWidth: 300, minHeight: 200)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    viewModel.closeForm()
                    dismiss()
                }
                .accessibilityIdentifier("admin-crypto-form-cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    let didSave: Bool
                    if let crypto = crypto {
                        didSave = viewModel.updateCrypto(crypto, nombre: nombre, simbolo: simbolo, precio: precio, coingeckoId: coingeckoId.isEmpty ? nil : coingeckoId)
                    } else {
                        didSave = viewModel.addCrypto(nombre: nombre, simbolo: simbolo, precio: precio, coingeckoId: coingeckoId.isEmpty ? nil : coingeckoId)
                    }
                    if didSave {
                        viewModel.closeForm()
                        dismiss()
                    }
                }
                .disabled(nombre.isEmpty || simbolo.isEmpty)
                .accessibilityIdentifier("admin-crypto-form-save")
            }
        }
        .alert("No se pudo guardar", isPresented: Binding(
            get: { viewModel.formErrorMessage != nil },
            set: { if !$0 { viewModel.clearFormError() } }
        )) {
            Button("Aceptar") { viewModel.clearFormError() }
        } message: {
            Text(viewModel.formErrorMessage ?? "Error desconocido")
        }
    }
}
