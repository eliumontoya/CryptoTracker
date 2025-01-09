import SwiftUI
import SwiftData

struct AdminCryptosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedCrypto: Crypto?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack {
            List {
                ForEach(cryptos) { crypto in
                    CryptoRowView(crypto: crypto)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCrypto = crypto
                            showingEditSheet = true
                        }
                }
                .onDelete(perform: deleteCryptos)
            }
            .navigationTitle("Cryptos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Agregar Crypto", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    CryptoFormView(mode: .add)
                }
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: { selectedCrypto = nil }) {
                if let crypto = selectedCrypto {
                    NavigationStack {
                        CryptoFormView(mode: .edit(crypto))
                    }
                }
            }
        }
    }
    
    private func deleteCryptos(at offsets: IndexSet) {
        for index in offsets {
            let crypto = cryptos[index]
            modelContext.delete(crypto)
        }
    }
}

struct CryptoRowView: View {
    let crypto: Crypto
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(crypto.nombre)
                    .font(.headline)
                Text("(\(crypto.simbolo))")
                    .foregroundColor(.secondary)
                Spacer()
                Text(crypto.precio.formatted(.currency(code: "USD")))
                    .font(.subheadline)
            }
            
            Text("Última actualización: \(crypto.ultimaActualizacion.formatted())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

enum CryptoFormMode {
    case add
    case edit(Crypto)
}

struct CryptoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mode: CryptoFormMode
    
    @State private var nombre: String = ""
    @State private var simbolo: String = ""
    @State private var precio: Decimal = 0.0
    
    var title: String {
        switch mode {
        case .add:
            return "Nueva Crypto"
        case .edit:
            return "Editar Crypto"
        }
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
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    save()
                }
                .disabled(nombre.isEmpty || simbolo.isEmpty)
            }
        }
        .onAppear {
            if case .edit(let crypto) = mode {
                nombre = crypto.nombre
                simbolo = crypto.simbolo
                precio = crypto.precio
            }
        }
    }
    
    private func save() {
        switch mode {
        case .add:
            let newCrypto = Crypto(nombre: nombre, simbolo: simbolo, precio: precio)
            modelContext.insert(newCrypto)
        case .edit(let crypto):
            crypto.nombre = nombre
            crypto.simbolo = simbolo
            crypto.precio = precio
            crypto.ultimaActualizacion = Date()
        }
        dismiss()
    }
}

#Preview {
    AdminCryptosView()
}
