import SwiftUI
import SwiftData

struct MovimientosSwapsView: View {
    private let dependencies: AppDependencyContainer
    @Query(sort: \Movimiento.fecha, order: .reverse) private var todos: [Movimiento]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: Movimiento?
    @State private var errorMessage: String?

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
    }

    /// Una fila por swap lógico: la pierna de salida (`.swapSalida`) con su pierna
    /// de entrada (`.swapEntrada`) localizada por `groupId`.
    private var swaps: [(salida: Movimiento, entrada: Movimiento?)] {
        todos
            .filter { $0.tipo == .swapSalida }
            .map { salida in
                let entrada = todos.first {
                    $0.groupId == salida.groupId && $0.tipo == .swapEntrada
                }
                return (salida, entrada)
            }
    }

    var body: some View {
        List {
            ForEach(swaps, id: \.salida.id) { par in
                MovimientoSwapRowView(salida: par.salida, entrada: par.entrada)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = par.salida
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos de Swaps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Nuevo Movimiento", systemImage: "plus")
                }
                .accessibilityIdentifier("movement-swap-add")
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                dependencies.makeMovimientoSwapFormView(movimiento: movimiento)
            }
        }
        .fullScreenCover(isPresented: $showingAddSheet) {
            NavigationStack {
                dependencies.makeMovimientoSwapFormView()
            }
        }
        #else
        .sheet(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                dependencies.makeMovimientoSwapFormView(movimiento: movimiento)
            }
            .adaptiveSheetFrame()
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                dependencies.makeMovimientoSwapFormView()
            }
            .adaptiveSheetFrame()
        }
        #endif
        .accessibilityIdentifier("movements-swaps-view")
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteMovimientos(at offsets: IndexSet) {
        let selectedMovimientos = offsets.map { swaps[$0].salida }
        Task {
            do {
                for movimiento in selectedMovimientos {
                    let viewModel = dependencies.makeMovimientoSwapViewModel(movimiento: movimiento)
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

struct MovimientoSwapRowView: View {
    let salida: Movimiento
    let entrada: Movimiento?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fecha y cryptos
            HStack {
                Text(Format.date(salida.fecha))
                    .font(.subheadline)
                Spacer()
                if let cryptoOrigen = salida.cryptoOrigen,
                   let cryptoDestino = salida.cryptoDestino {
                    Text("\(cryptoOrigen.simbolo) → \(cryptoDestino.simbolo)")
                        .font(.headline)
                }
            }

            // Cantidades y precios
            VStack(alignment: .leading, spacing: 4) {
                if let cryptoOrigen = salida.cryptoOrigen {
                    HStack {
                        Label {
                            Text("\(Format.crypto(salida.cantidadOrigen, symbol: cryptoOrigen.simbolo))")
                        } icon: {
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.red)
                        }
                        Text("@ \(Format.usd(salida.precioUSDOrigen))")
                            .font(.caption)
                    }
                }

                if let cryptoDestino = salida.cryptoDestino {
                    HStack {
                        Label {
                            Text("\(Format.crypto(entrada?.cantidadDestino ?? salida.cantidadDestino, symbol: cryptoDestino.simbolo))")
                        } icon: {
                            Image(systemName: "arrow.down.right")
                                .foregroundStyle(.green)
                        }
                        Text("@ \(Format.usd(entrada?.precioUSDDestino ?? salida.precioUSDDestino))")
                            .font(.caption)
                    }
                }
            }
            .font(.subheadline)

            // Cartera
            if let cartera = salida.cartera {
                Text("Cartera: \(cartera.nombre)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
