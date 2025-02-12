import SwiftUI
import SwiftData

struct AdminCryptosView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: AdminCryptosViewModel
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: AdminCryptosViewModel(modelContext: modelContext))
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
                    offsets.forEach { index in
                        viewModel.deleteCrypto(viewModel.cryptos[index])
                    }
                }
            }
            .navigationTitle("Cryptos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showAddForm() }) {
                        Label("Agregar Crypto", systemImage: "plus")
                    }
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
            .alert("¿Eliminar crypto?", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let crypto = viewModel.selectedCrypto {
                        viewModel.deleteCrypto(crypto)
                        viewModel.selectedCrypto = nil
                    }
                }
            }
        }
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
                Text(calculos.precio.formatted(.currency(code: "USD")))
                    .font(.subheadline)
            }
            
            HStack {
                let calculos = viewModel.getCalculosCrypto(crypto)
                Text("Última actualización: \(calculos.ultimaActualizacion.formatted())")
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
    
    init(viewModel: AdminCryptosViewModel, crypto: Crypto? = nil) {
        self.viewModel = viewModel
        self.crypto = crypto
        _nombre = State(initialValue: crypto?.nombre ?? "")
        _simbolo = State(initialValue: crypto?.simbolo ?? "")
        _precio = State(initialValue: crypto?.precio ?? 0.0)
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
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    viewModel.closeForm()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    if let crypto = crypto {
                        viewModel.updateCrypto(crypto, nombre: nombre, simbolo: simbolo, precio: precio)
                    } else {
                        viewModel.addCrypto(nombre: nombre, simbolo: simbolo, precio: precio)
                    }
                    viewModel.closeForm()
                    dismiss()
                }
                .disabled(nombre.isEmpty || simbolo.isEmpty)
            }
        }
    }
}

