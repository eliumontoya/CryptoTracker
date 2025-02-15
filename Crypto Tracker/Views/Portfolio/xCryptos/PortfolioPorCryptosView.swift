import SwiftUI
import SwiftData

struct PortfolioPorCryptosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    
    @StateObject private var viewModel: PortfolioPorCryptosViewModel = PortfolioPorCryptosViewModel(
        modelContext: ModelContext(try! ModelContainer(for: Cartera.self))
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerWithMenuView
                
                if viewModel.isLoading {
                    MovimientoLoadingView()
                } else {
                    portfolioTableView
                }
            }
            .padding()
        }
        .navigationTitle("Portafolio por Cryptos")
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.actualizarPortfolio(carteras: carteras, cryptos: cryptos)
        }
        .onChange(of: carteras) { _, newCarteras in
            viewModel.actualizarPortfolio(carteras: newCarteras, cryptos: cryptos)
        }
        .onChange(of: cryptos) { _, newCryptos in
            viewModel.actualizarPortfolio(carteras: carteras, cryptos: newCryptos)
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
        .sheet(item: $viewModel.selectedCrypto) { crypto in
            CryptoDetailView(crypto: crypto)
                .onDisappear {
                    viewModel.actualizarPortfolio(carteras: carteras, cryptos: cryptos)
                }
        }
        .applyMovimientoSheets(
            showingEntradaForm: $viewModel.showingEntradaForm,
            showingSalidaForm: $viewModel.showingSalidaForm,
            showingEntreCarterasForm: $viewModel.showingEntreCarterasForm,
            showingSwapForm: $viewModel.showingSwapForm,
            viewModel: viewModel
        )
    }
    
    private var headerWithMenuView: some View {
        HStack {
            Text("Portafolio por Cryptos")
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Menu {
                Button(action: { viewModel.showingEntradaForm = true }) {
                    Label("Nueva Entrada", systemImage: "arrow.down.circle")
                }
                
                Button(action: { viewModel.showingSalidaForm = true }) {
                    Label("Nueva Salida", systemImage: "arrow.up.circle")
                }
                
                Button(action: { viewModel.showingEntreCarterasForm = true }) {
                    Label("Nueva Transferencia", systemImage: "arrow.left.arrow.right")
                }
                
                Button(action: { viewModel.showingSwapForm = true }) {
                    Label("Nuevo Swap", systemImage: "arrow.triangle.2.circlepath")
                }
            } label: {
                Label("Agregar Movimiento", systemImage: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var portfolioTableView: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                CryptoPortfolioHeaderRow()
                
                ForEach(viewModel.cryptoSummaries) { summary in
                    CryptoPortfolioRow(summary: summary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedCrypto = summary.crypto
                        }
                }
                
                if !viewModel.cryptoSummaries.isEmpty {
                    Divider()
                    CryptoPortfolioTotalRow(summaries: viewModel.cryptoSummaries)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - View Modifiers
private extension View {
    func applyMovimientoSheets(
        showingEntradaForm: Binding<Bool>,
        showingSalidaForm: Binding<Bool>,
        showingEntreCarterasForm: Binding<Bool>,
        showingSwapForm: Binding<Bool>,
        viewModel: PortfolioPorCryptosViewModel
    ) -> some View {
        self
            .sheet(isPresented: showingEntradaForm) {
                NavigationStack {
                    viewModel.crearFormMovimientoEntrada()
                }
                .frame(minWidth: 500, minHeight: 700)
            }
            .sheet(isPresented: showingSalidaForm) {
                NavigationStack {
                    viewModel.crearFormMovimientoSalida()
                }
                .frame(minWidth: 500, minHeight: 700)
            }
            .sheet(isPresented: showingEntreCarterasForm) {
                NavigationStack {
                    viewModel.crearFormMovimientoEntreCarteras()
                }
                .frame(minWidth: 500, minHeight: 700)
            }
            .sheet(isPresented: showingSwapForm) {
                NavigationStack {
                    viewModel.crearFormMovimientoSwap()
                }
                .frame(minWidth: 500, minHeight: 700)
            }
    }
}

#Preview {
    PortfolioPorCryptosView()
        .withPreviewContainer()
}
