import SwiftUI

struct PortfolioDetalleView: View {
    private let dependencies: AppDependencyContainer
    @StateObject private var viewModel: PortfolioDetalleViewModel
    
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
        .accessibilityIdentifier("portfolio-detail-view")
        .navigationTitle(String(localized: "menu_portfolio_by_wallets"))
        .onAppear {
            viewModel.actualizarPortfolio()
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
                                viewModel.actualizarPortfolio()
                            }
                        )
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Segunda columna del renglón
                    if (renglon * 2 + 1) < viewModel.carterasDetail.count {
                        dependencies.makeCarteraDetailView(
                            carteraDetail: viewModel.carterasDetail[renglon * 2 + 1],
                            onUpdateData: {
                                viewModel.actualizarPortfolio()
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
