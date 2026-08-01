import SwiftUI
import SwiftData

struct PortfolioDetalleView: View {
    private let dependencies: AppDependencyContainer
    @StateObject private var viewModel: PortfolioDetalleViewModel
    
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    
    init(viewModel: PortfolioDetalleViewModel, dependencies: AppDependencyContainer) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
    }
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contenidoPortfolio
            }
        }
        .navigationTitle("Desglose por Carteras")
        .onAppear {
            viewModel.actualizarPortfolio(
                carteras: carteras,
                cryptos: cryptos
            )
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
    
    private var contenidoPortfolio: some View {
        VStack(spacing: 20) {
            ForEach(0..<viewModel.numeroRenglones, id: \.self) { renglon in
                HStack(alignment: .top, spacing: 20) {
                    // Primera columna del renglón
                    if renglon * 2 < viewModel.carterasDetail.count {

                        dependencies.makeCarteraDetailView(
                            carteraDetail: viewModel.carterasDetail[renglon * 2],
                            onUpdateData: {
                                viewModel.actualizarPortfolio(
                                    carteras: carteras,
                                    cryptos: cryptos
                                )
                            }
                        )
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Segunda columna del renglón
                    if (renglon * 2 + 1) < viewModel.carterasDetail.count {
                        dependencies.makeCarteraDetailView(
                            carteraDetail: viewModel.carterasDetail[renglon * 2 + 1],
                            onUpdateData: {
                                viewModel.actualizarPortfolio(
                                    carteras: carteras,
                                    cryptos: cryptos
                                )
                            }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    let dependencies = AppDependencyContainer(modelContext: PreviewContainer.shared.context)
    return PortfolioDetalleView(viewModel: dependencies.portfolioDetalleViewModel, dependencies: dependencies)
        .withPreviewContainer()
}
