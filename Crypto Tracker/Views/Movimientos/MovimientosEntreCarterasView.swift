import SwiftUI
import SwiftData

struct MovimientosEntreCarterasView: View {
    private let dependencies: AppDependencyContainer
    @Query(sort: \Movimiento.fecha, order: .reverse) private var todos: [Movimiento]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: Movimiento?
    @State private var errorMessage: String?

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
                .accessibilityIdentifier("movement-transfer-add")
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
        .accessibilityIdentifier("movements-transfer-view")
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteMovimientos(at offsets: IndexSet) {
        let selectedMovimientos = offsets.map { transferencias[$0].salida }
        Task {
            do {
                for movimiento in selectedMovimientos {
                    let viewModel = dependencies.makeMovimientoEntreCarterasViewModel(movimiento: movimiento)
                    try await viewModel.delete()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
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
