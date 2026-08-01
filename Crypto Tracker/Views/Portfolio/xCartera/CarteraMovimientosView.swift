import SwiftUI
import SwiftData

struct CarteraMovimientosView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CarteraMovimientosViewModel
    
    init(cartera: Cartera, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: CarteraMovimientosViewModel(
            cartera: cartera,
            modelContext: modelContext
        ))
    }
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            movimientosContent
        }
        #else
        movimientosContent
        #endif
    }
    
    private var movimientosContent: some View {
        VStack(spacing: 20) {
            headerView
            
            if viewModel.isLoading {
                MovimientoLoadingView()
            } else if viewModel.movimientos.isEmpty {
                MovimientoEmptyView(message: "No hay movimientos registrados")
            } else {
                movimientosList
            }
        }
        .padding()
        .onAppear {
            viewModel.cargarMovimientos()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(item: $viewModel.selectedMovimientoDetalle) { movimientoDetalle in
            NavigationStack {
                MovimientoSearchView(movimientoDetalle: movimientoDetalle, modelContext: modelContext)
            }
            .onDisappear {
                viewModel.cargarMovimientos()
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Volver")
                }
            }
            Spacer()
            Text(viewModel.carteraNombre)
                .font(.title2)
                .bold()
            Spacer()
        }
        .padding(.bottom)
    }
    
    private var movimientosList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.movimientos) { movimiento in
                    #if os(iOS)
                    NavigationLink(destination: MovimientoSearchView(
                        movimientoDetalle: movimiento,
                        modelContext: modelContext
                    )) {
                        MovimientoDetalleRowView(movimiento: movimiento, onTap: {})
                    }
                    .buttonStyle(.plain)
                    #else
                    MovimientoDetalleRowView(
                        movimiento: movimiento,
                        onTap: {
                            print("Seleccionado movimiento: \(movimiento.id)")
                            viewModel.selectedMovimientoDetalle = movimiento
                        }
                    )
                    #endif
                }
            }
            .padding(.horizontal)
        }
    }
}
