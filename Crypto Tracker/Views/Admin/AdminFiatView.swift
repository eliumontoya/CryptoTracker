import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdminFiatView: View {
    @StateObject private var viewModel: AdminFiatViewModel
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: AdminFiatViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.fiats) { fiat in
                FiatRowView(fiat: fiat, precio: viewModel.getPrecioUSD(fiat))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedFiat = fiat
                        viewModel.showEditForm(for: fiat)
                    }
            }
            .onDelete { offsets in
                for index in offsets {
                    let fiat = viewModel.fiats[index]
                    if viewModel.canDeleteFiat(fiat) {
                        viewModel.deleteFiat(fiat)
                    } else {
                        viewModel.selectedFiat = fiat
                        viewModel.showingDeleteAlert = true
                    }
                }
            }
        }
        .navigationTitle("Monedas FIAT")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showAddForm() }) {
                    Label("Agregar FIAT", systemImage: "plus")
                }
            }
        }
        .sheet(item: $viewModel.formState) { formState in
            NavigationStack {
                FiatFormView(viewModel: viewModel, mode: formState)
            }
        }
        .alert("¿Eliminar FIAT?", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                if let fiat = viewModel.selectedFiat {
                    viewModel.deleteFiat(fiat)
                    viewModel.selectedFiat = nil
                }
            }
        } message: {
            Text("¿Está seguro de eliminar esta moneda? Esta acción no se puede deshacer.")
        }
    }
}

// MARK: - Vistas Auxiliares
struct FiatRowView: View {
    let fiat: FIAT
    let precio: Decimal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fiat.nombre)
                    .font(.headline)
                Text("(\(fiat.simbolo))")
                    .foregroundColor(.secondary)
                Spacer()
                Text(precio.formatted(.currency(code: "USD")))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FiatFormView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: AdminFiatViewModel
    let mode: FiatFormState
    
    @State private var nombre: String = ""
    @State private var simbolo: String = ""
    @State private var precioUSD: Decimal = 1.0
    
    var title: String {
        switch mode {
        case .add:
            return "Nueva Moneda FIAT"
        case .edit:
            return "Editar Moneda FIAT"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Nombre", text: $nombre)
                .textFieldStyle(.roundedBorder)
            
            TextField("Símbolo", text: $simbolo)
                .textFieldStyle(.roundedBorder)
            
            TextField("Precio en USD", value: $precioUSD, format: .currency(code: "USD"))
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
                    save()
                    viewModel.closeForm()
                    dismiss()
                }
                .disabled(nombre.isEmpty || simbolo.isEmpty || precioUSD <= 0)
            }
        }
        .onAppear {
            if case .edit(let fiat) = mode {
                nombre = fiat.nombre
                simbolo = fiat.simbolo
                precioUSD = fiat.precioUSD
            }
        }
    }
    
    private func save() {
        switch mode {
        case .add:
            viewModel.addFiat(nombre: nombre, simbolo: simbolo, precioUSD: precioUSD)
        case .edit(let fiat):
            viewModel.updateFiat(fiat, nombre: nombre, simbolo: simbolo, precioUSD: precioUSD)
        }
    }
}
