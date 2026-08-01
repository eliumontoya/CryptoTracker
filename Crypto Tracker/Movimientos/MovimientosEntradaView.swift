import SwiftUI
import SwiftData

struct MovimientosEntradaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoIngreso.fecha, order: .reverse) private var movimientos: [MovimientoIngreso]
    
    @ObservedObject private var viewModel: MovimientosEntradaListViewModel
    
    // Estados para controlar los sheets
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var selectedMovimiento: MovimientoIngreso?
    
    // Inicializador que recibe directamente el ViewModel
    init(viewModel: MovimientosEntradaListViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            // Lista principal
            List {
                ForEach(movimientos) { movimiento in
                    MovimientoEntradaRowView(movimiento: movimiento)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.prepareForEdit(movimiento: movimiento)
                            selectedMovimiento = movimiento
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingEditSheet = true
                            }
                        }
                }
                .onDelete(perform: deleteMovimientos)
            }
            
            // Overlay de carga
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .navigationTitle("Movimientos de Entrada")
        // Usamos toolbar de manera compatible con macOS
        .toolbar {
            Button(action: {
                viewModel.prepareForAdd()
                showingAddSheet = true
            }) {
                Label("Agregar", systemImage: "plus")
            }
            .disabled(viewModel.isLoading)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingAddSheet) {
            NavigationStack {
                MovimientoEntradaFormView(viewModel: viewModel.entradaViewModel)
            }
            .onDisappear {
                viewModel.refreshData()
            }
        }
        .fullScreenCover(isPresented: $showingEditSheet) {
            if let movimiento = selectedMovimiento {
                NavigationStack {
                    MovimientoEntradaFormView(viewModel: viewModel.entradaViewModel)
                        .onAppear {
                            if viewModel.entradaViewModel.movimiento?.id != movimiento.id {
                                viewModel.prepareForEdit(movimiento: movimiento)
                            }
                        }
                }
                .onDisappear {
                    viewModel.refreshData()
                    selectedMovimiento = nil
                }
            }
        }
        #else
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MovimientoEntradaFormView(viewModel: viewModel.entradaViewModel)
            }
            .onDisappear {
                viewModel.refreshData()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let movimiento = selectedMovimiento {
                NavigationStack {
                    MovimientoEntradaFormView(viewModel: viewModel.entradaViewModel)
                        .onAppear {
                            if viewModel.entradaViewModel.movimiento?.id != movimiento.id {
                                viewModel.prepareForEdit(movimiento: movimiento)
                            }
                        }
                }
                .onDisappear {
                    viewModel.refreshData()
                    selectedMovimiento = nil
                }
            }
        }
        #endif
        .alert("Error", isPresented: $viewModel.hasError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private func deleteMovimientos(at offsets: IndexSet) {
        Task {
            do {
                try await viewModel.deleteMovimientos(at: offsets, from: movimientos)
            } catch {
                // El error se manejará en el ViewModel
            }
        }
    }
}

// MARK: - Fila de Movimiento Entrada
struct MovimientoEntradaRowView: View {
    let movimiento: MovimientoIngreso
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primera línea: Fecha y Crypto
            HStack {
                Text(movimiento.fecha.formatted(date: .abbreviated, time: .shortened))
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
                    Text("Cantidad: \(movimiento.cantidadCrypto.formatted()) \(crypto.simbolo)")
                }
                Spacer()
                Text("Precio USD: \(movimiento.precioUSD.formatted(.currency(code: "USD")))")
            }
            .font(.subheadline)
            
            // Tercera línea: Cartera y totales
            HStack {
                if let cartera = movimiento.cartera {
                    Text("Cartera: \(cartera.nombre)")
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Total USD: \(movimiento.valorTotalUSD.formatted(.currency(code: "USD")))")
                    if movimiento.usaFiatAlterno,
                       let fiat = movimiento.fiatAlterno,
                       let valorFiat = movimiento.valorTotalFiatAlterno {
                        Text("Total \(fiat.simbolo): \(valorFiat.formatted(.currency(code: fiat.simbolo)))")
                            .foregroundStyle(.green)
                    }
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
 
