import SwiftUI
import SwiftData
struct CarteraCryptoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CarteraCryptoDetailViewModel
    
    init(crypto: Crypto, cartera: Cartera) {
        _viewModel = StateObject(wrappedValue: CarteraCryptoDetailViewModel(
            crypto: crypto,
            cartera: cartera
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if viewModel.movimientos.isEmpty {
                ContentUnavailableView(
                    "No hay movimientos",
                    systemImage: "list.bullet.rectangle.portrait",
                    description: Text("No se encontraron movimientos para esta crypto en esta cartera")
                )
                .frame(maxHeight: .infinity)
            } else {
                movimientosList
            }
        }
        .padding()
        .onAppear {
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
            VStack(spacing: 4) {
                Text(viewModel.title)
                    .font(.title2)
                    .bold()
                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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
                            print("Seleccionado movimiento: \(movimiento.id)")
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
    let cartera = Cartera(nombre: "Mi Cartera", simbolo: "MC")
    
    return CarteraCryptoDetailView(crypto: crypto, cartera: cartera)
        .modelContainer(previewContainer.container)
}
