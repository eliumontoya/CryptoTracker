import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdminCarterasView: View {
    @StateObject private var viewModel: AdminCarterasViewModel
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: AdminCarterasViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(viewModel.carteras) { cartera in
                    let calculos = viewModel.getCalculosCartera(cartera)
                    CarteraRowView(
                        cartera: cartera,
                        valorTotalUSD: calculos.valorTotal,
                        resumenCryptos: calculos.resumen,
                        gananciaPerdida: calculos.ganancia
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.showEditForm(for: cartera)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let cartera = viewModel.carteras[index]
                        if viewModel.canDeleteCartera(cartera) {
                            viewModel.deleteCartera(cartera)
                        } else {
                            viewModel.selectedCartera = cartera
                            viewModel.showingDeleteAlert = true
                        }
                    }
                }
            }
            .navigationTitle("Carteras")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showAddForm() }) {
                        Label("Agregar Cartera", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $viewModel.formState) { formState in
                NavigationStack {
                    CarteraFormView(formState: formState) { nombre, simbolo in
                        switch formState {
                        case .add:
                            viewModel.addCartera(nombre: nombre, simbolo: simbolo)
                        case .edit(let cartera):
                            viewModel.updateCartera(cartera, nombre: nombre, simbolo: simbolo)
                        }
                        viewModel.closeForm()
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .alert("¿Eliminar cartera?", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let cartera = viewModel.selectedCartera {
                        viewModel.deleteCartera(cartera)
                        viewModel.selectedCartera = nil
                    }
                }
            } message: {
                Text("Esta acción no se puede deshacer. ¿Está seguro de eliminar esta cartera?")
            }
        }
        .onDisappear {
            viewModel.clearCache()
        }
    }
}

struct CarteraRowView: View {
    let cartera: Cartera
    let valorTotalUSD: Decimal
    let resumenCryptos: String
    let gananciaPerdida: (ganancia: Decimal, esGanancia: Bool)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(cartera.nombre)
                    .font(.headline)
                Text("(\(cartera.simbolo))")
                    .foregroundColor(.secondary)
                Spacer()
                Text(valorTotalUSD.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            if !resumenCryptos.isEmpty {
                Text("Cryptos: \(resumenCryptos)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(gananciaPerdida.esGanancia ? "Ganancia:" : "Pérdida:")
                    .font(.caption)
                Text(gananciaPerdida.ganancia.formatted(.currency(code: "USD")))
                    .font(.caption)
                    .foregroundColor(gananciaPerdida.esGanancia ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CarteraFormView: View {
    @Environment(\.dismiss) private var dismiss
    let formState: CarteraFormState
    let onSave: (String, String) -> Void
    
    @State private var nombre: String = ""
    @State private var simbolo: String = ""
    
    var title: String {
        switch formState {
        case .add:
            return "Nueva Cartera"
        case .edit:
            return "Editar Cartera"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Nombre", text: $nombre)
                .textFieldStyle(.roundedBorder)
            TextField("Símbolo", text: $simbolo)
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
                    onSave(nombre, simbolo)
                    dismiss()
                }
                .disabled(nombre.isEmpty || simbolo.isEmpty)
            }
        }
        .onAppear {
            if case .edit(let cartera) = formState {
                nombre = cartera.nombre
                simbolo = cartera.simbolo
            }
        }
    }
}
