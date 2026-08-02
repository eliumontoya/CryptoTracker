import SwiftUI
import SwiftData

struct MovimientosEntreCarterasView: View {
    private let dependencies: AppDependencyContainer
    @Query(sort: \MovimientoEntreCarteras.fecha, order: .reverse) private var movimientos: [MovimientoEntreCarteras]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: MovimientoEntreCarteras?
    
    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
    }
    
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoEntreCarterasRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos Entre Carteras")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Nuevo Movimiento", systemImage: "plus")
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                dependencies.makeMovimientoEntreCarterasFormView(movimiento: movimiento)
            }
        }
        .fullScreenCover(isPresented: $showingAddSheet) {
            NavigationStack {
                dependencies.makeMovimientoEntreCarterasFormView()
            }
        }
        #else
        .sheet(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                dependencies.makeMovimientoEntreCarterasFormView(movimiento: movimiento)
            }
            .adaptiveSheetFrame()
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                dependencies.makeMovimientoEntreCarterasFormView()
            }
            .adaptiveSheetFrame()
        }
        #endif
    }
    
    private func deleteMovimientos(at offsets: IndexSet) {
        Task {
            for index in offsets {
                dependencies.modelContext.delete(movimientos[index])
            }
            try? dependencies.modelContext.save()
        }
    }
}

struct MovimientoEntreCarterasRowView: View {
    let movimiento: MovimientoEntreCarteras
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Format.date(movimiento.fecha))
                    .font(.subheadline)
                Spacer()
                if let crypto = movimiento.crypto {
                    Text(crypto.simbolo)
                        .font(.headline)
                }
            }
            
            HStack {
                if let crypto = movimiento.crypto {
                    Text("Salida: \(Format.crypto(movimiento.cantidadCryptoSalida, symbol: crypto.simbolo))")
                    Text("Entrada: \(Format.crypto(movimiento.cantidadCryptoEntrada, symbol: crypto.simbolo))")
                }
            }
            .font(.subheadline)
            
            HStack {
                Image(systemName: "arrow.right")
                    .foregroundStyle(.blue)
                if let carteraOrigen = movimiento.carteraOrigen,
                   let carteraDestino = movimiento.carteraDestino {
                    Text("\(carteraOrigen.nombre) → \(carteraDestino.nombre)")
                        .font(.caption)
                }
            }
            
            // Mostrar comisión si existe
            if let crypto = movimiento.crypto,
               movimiento.cantidadCryptoComision > 0 {
                HStack {
                    Text("Comisión:")
                        Text("\(Format.crypto(movimiento.cantidadCryptoComision, symbol: crypto.simbolo))")
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
