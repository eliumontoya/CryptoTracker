import SwiftUI
import SwiftData

struct MovimientosSalidaView: View {
    private let dependencies: AppDependencyContainer
    @Query(filter: #Predicate<Movimiento> { $0.tipoRaw == "salida" },
           sort: \Movimiento.fecha, order: .reverse) private var movimientos: [Movimiento]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: Movimiento?
    
    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
    }
 
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoSalidaRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos de Salida")
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
                dependencies.makeMovimientoSalidaFormView(movimiento: movimiento)
            }
        }
        .fullScreenCover(isPresented: $showingAddSheet) {
            NavigationStack {
                dependencies.makeMovimientoSalidaFormView()
            }
        }
        #else
        .sheet(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                dependencies.makeMovimientoSalidaFormView(movimiento: movimiento)
            }
            .adaptiveSheetFrame()
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                dependencies.makeMovimientoSalidaFormView()
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

struct MovimientoSalidaRowView: View {
    let movimiento: Movimiento
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primera línea: Fecha y Crypto
            HStack {
                Text(Format.date(movimiento.fecha))
                    .font(.subheadline)
                Spacer()
                if let crypto = movimiento.crypto {
                    Text(crypto.simbolo)
                        .font(.headline)
                }
            }
            
            // Segunda línea: Cantidad y Precio USD
            HStack {
                if let crypto = movimiento.crypto {
                    Text("Cantidad: \(Format.crypto(movimiento.cantidadCrypto, symbol: crypto.simbolo))")
                }
                Spacer()
                Text("Precio USD: \(Format.usd(movimiento.precioUSD))")
            }
            .font(.subheadline)
            
            // Tercera línea: Cartera y totales
            HStack {
                if let cartera = movimiento.cartera {
                    Text("Cartera: \(cartera.nombre)")
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Total USD: \(Format.usd(movimiento.valorTotalUSD))")
                    if movimiento.usaFiatAlterno,
                       let fiat = movimiento.fiatAlterno,
                       let valorFiat = movimiento.valorTotalFiatAlterno {
                        Text("Total \(fiat.simbolo): \(Format.currency(valorFiat, code: fiat.simbolo))")
                            .foregroundStyle(.green)
                    }
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
