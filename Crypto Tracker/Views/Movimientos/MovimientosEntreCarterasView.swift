import SwiftUI
import SwiftData

struct MovimientosEntreCarterasView: View {
    private let dependencies: AppDependencyContainer
    @Query(sort: \Movimiento.fecha, order: .reverse) private var todos: [Movimiento]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: Movimiento?

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
    }

    /// Una fila por transferencia lógica: la pierna de salida (`.transferenciaSalida`)
    /// con su pierna de entrada (`.transferenciaEntrada`) localizada por `groupId`.
    private var transferencias: [(salida: Movimiento, entrada: Movimiento?)] {
        todos
            .filter { $0.tipo == .transferenciaSalida }
            .map { salida in
                let entrada = todos.first {
                    $0.groupId == salida.groupId && $0.tipo == .transferenciaEntrada
                }
                return (salida, entrada)
            }
    }

    var body: some View {
        List {
            ForEach(transferencias, id: \.salida.id) { par in
                MovimientoEntreCarterasRowView(salida: par.salida, entrada: par.entrada)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = par.salida
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
                let par = transferencias[index]
                if let entrada = par.entrada {
                    dependencies.modelContext.delete(entrada)
                }
                dependencies.modelContext.delete(par.salida)
            }
            try? dependencies.modelContext.save()
        }
    }
}

struct MovimientoEntreCarterasRowView: View {
    let salida: Movimiento
    let entrada: Movimiento?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Format.date(salida.fecha))
                    .font(.subheadline)
                Spacer()
                if let crypto = salida.crypto {
                    Text(crypto.simbolo)
                        .font(.headline)
                }
            }

            HStack {
                if let crypto = salida.crypto {
                    Text("Salida: \(Format.crypto(salida.cantidadCryptoSalida, symbol: crypto.simbolo))")
                    Text("Entrada: \(Format.crypto(entrada?.cantidadCryptoEntrada ?? salida.cantidadCryptoEntrada, symbol: crypto.simbolo))")
                }
            }
            .font(.subheadline)

            HStack {
                Image(systemName: "arrow.right")
                    .foregroundStyle(.blue)
                if let carteraOrigen = salida.carteraOrigen,
                   let carteraDestino = salida.carteraDestino {
                    Text("\(carteraOrigen.nombre) → \(carteraDestino.nombre)")
                        .font(.caption)
                }
            }

            // Mostrar comisión si existe
            if let crypto = salida.crypto,
               salida.cantidadCryptoComision > 0 {
                HStack {
                    Text("Comisión:")
                        Text("\(Format.crypto(salida.cantidadCryptoComision, symbol: crypto.simbolo))")
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
