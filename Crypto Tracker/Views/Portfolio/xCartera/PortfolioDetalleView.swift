import SwiftUI
import SwiftData

struct PortfolioDetalleView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: PortfolioDetalleViewModel
    
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    init() {
        // El StateObject debe inicializarse usando _varName para evitar problemas de memoria
        _viewModel = StateObject(wrappedValue: PortfolioDetalleViewModel(
            modelContext: ModelContext(try! ModelContainer(for: Cartera.self))
        ))
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
                cryptos: cryptos,
                fiats: fiats
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
                        CarteraDetailView(
                            carteraDetail: viewModel.carterasDetail[renglon * 2],
                            onUpdateData: {
                                viewModel.actualizarPortfolio(
                                    carteras: carteras,
                                    cryptos: cryptos,
                                    fiats: fiats
                                )
                            }
                        )
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Segunda columna del renglón
                    if (renglon * 2 + 1) < viewModel.carterasDetail.count {
                        CarteraDetailView(
                            carteraDetail: viewModel.carterasDetail[renglon * 2 + 1],
                            onUpdateData: {
                                viewModel.actualizarPortfolio(
                                    carteras: carteras,
                                    cryptos: cryptos,
                                    fiats: fiats
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
    PortfolioDetalleView()
        .withPreviewContainer()
}
