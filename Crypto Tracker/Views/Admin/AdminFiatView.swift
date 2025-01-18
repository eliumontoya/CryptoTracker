import SwiftUI
import SwiftData

struct AdminFiatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedFiat: FIAT?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack {
            List {
                ForEach(fiats) { fiat in
                    FiatRowView(fiat: fiat)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFiat = fiat
                            showingEditSheet = true
                        }
                }
                .onDelete(perform: deleteFiats)
            }
            .navigationTitle("Monedas FIAT")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Agregar FIAT", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $selectedFiat) { fiat in
                            NavigationStack {
                                FiatFormView(mode: fiat.id == nil ? .add : .edit(fiat))
                            }
                        }
            .sheet(isPresented: $showingAddSheet) {
                        NavigationStack {
                            FiatFormView(mode: .add)
                        }
                    }
            .alert("¿Eliminar FIAT?", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let fiat = selectedFiat {
                        modelContext.delete(fiat)
                        selectedFiat = nil
                    }
                }
            } message: {
                Text("¿Está seguro de eliminar esta moneda? Esta acción no se puede deshacer.")
            }
        }
    }
    
    private func deleteFiats(at offsets: IndexSet) {
        for index in offsets {
            let fiat = fiats[index]
            if fiat.movimientosIngreso.isEmpty && fiat.movimientosEgreso.isEmpty {
                modelContext.delete(fiat)
            } else {
                selectedFiat = fiat
                showingDeleteAlert = true
            }
        }
    }
}

struct FiatRowView: View {
    let fiat: FIAT
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fiat.nombre)
                    .font(.headline)
                Text("(\(fiat.simbolo))")
                    .foregroundColor(.secondary)
                Spacer()
                Text(fiat.precioUSD.formatted(.currency(code: "USD")))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

enum FiatFormMode {
    case add
    case edit(FIAT)
}

struct FiatFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mode: FiatFormMode
    
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
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    save()
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
            let newFiat = FIAT(nombre: nombre, simbolo: simbolo, precioUSD: precioUSD)
            modelContext.insert(newFiat)
        case .edit(let fiat):
            fiat.nombre = nombre
            fiat.simbolo = simbolo
            fiat.precioUSD = precioUSD
        }
        dismiss()
    }
}

#Preview {
    AdminFiatView()
        .withPreviewContainer()
}
