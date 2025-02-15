import SwiftUI
import SwiftData

struct CryptoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var carteras: [Cartera]
    @StateObject private var viewModel: CryptoDetailViewModel
    
    init(crypto: Crypto) {
        _viewModel = StateObject(wrappedValue: CryptoDetailViewModel(
            crypto: crypto,
            carteras: []  // Se actualizará con @Query
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            
            if viewModel.isLoading {
                MovimientoLoadingView()
            } else if viewModel.movimientos.isEmpty {
                MovimientoEmptyView(message: "No hay movimientos para esta crypto")
            } else {
                movimientosList
            }
        }
        .padding()
        .onChange(of: carteras) { _, newCarteras in
            viewModel.carteras = newCarteras
            viewModel.cargarMovimientos()
        }
        .onAppear {
            viewModel.carteras = carteras
            viewModel.cargarMovimientos()
        }
        .sheet(item: $viewModel.selectedMovimientoDetalle) { movimientoDetalle in
            NavigationStack {
                MovimientoSearchView(movimientoDetalle: movimientoDetalle)
            }
            .onDisappear {
                viewModel.cargarMovimientos()
            }
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
            Text(viewModel.title)
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
                    MovimientoDetalleRowView(
                        movimiento: movimiento,
                        onTap: {
                            viewModel.selectedMovimientoDetalle = movimiento
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    let previewContainer = PreviewContainer.shared
    let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 45000)
    
    return CryptoDetailView(crypto: crypto)
        .modelContainer(previewContainer.container)
}
