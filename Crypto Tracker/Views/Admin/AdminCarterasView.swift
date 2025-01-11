import SwiftUI
import SwiftData

struct AdminCarterasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedCartera: Cartera?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack {
            List {
                ForEach(carteras) { cartera in
                    CarteraRowView(cartera: cartera)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCartera = cartera
                            showingEditSheet = true
                        }
                }
                .onDelete(perform: deleteCarteras)
            }
            .navigationTitle("Carteras")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Label("Agregar Cartera", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    CarteraFormView(mode: .add)
                }
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: { selectedCartera = nil }) {
                if let cartera = selectedCartera {
                    NavigationStack {
                        CarteraFormView(mode: .edit(cartera))
                    }
                }
            }
            .alert("¿Eliminar cartera?", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let cartera = selectedCartera {
                        modelContext.delete(cartera)
                        selectedCartera = nil
                    }
                }
            } message: {
                Text("Esta acción no se puede deshacer. ¿Está seguro de eliminar esta cartera?")
            }
        }
    }
    
    private func deleteCarteras(at offsets: IndexSet) {
        for index in offsets {
            let cartera = carteras[index]
            // Verificar si la cartera tiene movimientos antes de eliminar
            if cartera.movimientosIngreso.isEmpty &&
               cartera.movimientosEgreso.isEmpty &&
               cartera.movimientosEntrada.isEmpty &&
               cartera.movimientosSalida.isEmpty &&
               cartera.swaps.isEmpty {
                modelContext.delete(cartera)
            } else {
                selectedCartera = cartera
                showingDeleteAlert = true
            }
        }
    }
}

struct CarteraRowView: View {
    let cartera: Cartera
    
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
            
            // Mostrar resumen de cryptos en la cartera
            if !cartera.movimientosIngreso.isEmpty {
                Text("Cryptos: \(resumenCryptos)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mostrar balance general
            HStack {
                let (ganancia, esGanancia) = calcularGananciaPerdida()
                Text(esGanancia ? "Ganancia:" : "Pérdida:")
                    .font(.caption)
                Text(ganancia.formatted(.currency(code: "USD")))
                    .font(.caption)
                    .foregroundColor(esGanancia ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var valorTotalUSD: Decimal {
        let cryptos = Set(cartera.movimientosIngreso.compactMap { $0.crypto })
        return cryptos.reduce(Decimal(0)) { total, crypto in
            let balance = calcularBalanceCrypto(crypto)
            return total + (balance * (crypto.precio))
        }
    }
    
    private var resumenCryptos: String {
        let cryptos = Set(cartera.movimientosIngreso.compactMap { $0.crypto })
        return cryptos.compactMap { $0.simbolo }.joined(separator: ", ")
    }
    
    private func calcularBalanceCrypto(_ crypto: Crypto) -> Decimal {
        let ingresos = cartera.movimientosIngreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 + $1.cantidadCrypto }
        
        let egresos = cartera.movimientosEgreso
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 + $1.cantidadCrypto }
            
        let transferenciasEntrada = cartera.movimientosEntrada
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 + $1.cantidadCryptoEntrada }
        
        let transferenciasSalida = cartera.movimientosSalida
            .filter { $0.crypto?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 + $1.cantidadCryptoSalida }
        
        let swapsEntrada = cartera.swaps
            .filter { $0.cryptoDestino?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 + $1.cantidadDestino }
        
        let swapsSalida = cartera.swaps
            .filter { $0.cryptoOrigen?.id == crypto.id }
            .reduce(into: Decimal(0)) { $0 + $1.cantidadOrigen }
        
        return ingresos + transferenciasEntrada + swapsEntrada -
               (egresos + transferenciasSalida + swapsSalida)
    }
    
    private func calcularGananciaPerdida() -> (Decimal, Bool) {
        let inversionTotalUSD = cartera.movimientosIngreso.reduce(Decimal(0)) { $0 + $1.valorTotalUSD }
        let gananciaPerdida = valorTotalUSD - inversionTotalUSD
        return (abs(gananciaPerdida), gananciaPerdida >= 0)
    }
}

enum CarteraFormMode {
    case add
    case edit(Cartera)
}

struct CarteraFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let mode: CarteraFormMode
    
    @State private var nombre: String = ""
    @State private var simbolo: String = ""
    
    var title: String {
        switch mode {
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
                    save()
                }
                .disabled(nombre.isEmpty || simbolo.isEmpty)
            }
        }
        .onAppear {
            if case .edit(let cartera) = mode {
                nombre = cartera.nombre
                simbolo = cartera.simbolo
            }
        }
    }
    
    private func save() {
        switch mode {
        case .add:
            let newCartera = Cartera(nombre: nombre, simbolo: simbolo)
            modelContext.insert(newCartera)
        case .edit(let cartera):
            cartera.nombre = nombre
            cartera.simbolo = simbolo
        }
        dismiss()
    }
}

#Preview {
    AdminCarterasView()
        .withPreviewContainer()
}
