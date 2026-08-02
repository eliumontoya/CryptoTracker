import SwiftUI
import SwiftData

// MARK: - Tipo auxiliar para sheet
struct IdentifiableCryptoCarteraPair: Identifiable {
    let id = UUID()
    let crypto: Crypto
    let cartera: Cartera
}

// MARK: - Vistas Auxiliares de Portfolio
struct CarteraHeaderView: View {
    let summary: CarteraDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(summary.cartera.nombre)
                    .font(.headline)
                Spacer()
                Text(Format.usd(summary.valorTotalUSD))
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            HStack {
                Text("Inversión: \(Format.usd(summary.totalInvertidoUSD))")
                Spacer()
                Text("Rentabilidad: \(Format.percent(summary.rentabilidadTotal))")
                    .foregroundStyle(summary.rentabilidadTotal >= 0 ? .green : .red)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Vista Principal de Cartera
struct CarteraDetailView: View {
    private let dependencies: AppDependencyContainer
    @StateObject private var viewModel: CarteraDetailViewModel
 
    init(carteraDetail: CarteraDetail, onUpdateData: @escaping () -> Void, dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: CarteraDetailViewModel(
            carteraDetail: carteraDetail,
            onUpdateData: onUpdateData
        ))
    }
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            cardContent
                .applyMovimientoSheets(
                    viewModel: viewModel,
                    dependencies: dependencies,
                    showingCarteraMovimientos: $viewModel.showingCarteraMovimientos,
                    showingEntradaForm: $viewModel.showingEntradaForm,
                    showingSalidaForm: $viewModel.showingSalidaForm,
                    showingEntreCarterasForm: $viewModel.showingEntreCarterasForm,
                    showingSwapForm: $viewModel.showingSwapForm
                )
        }
        #else
        cardContent
            .sheet(item: Binding(
                get: {
                    viewModel.selectedCryptoDetail.map { crypto, cartera in
                        IdentifiableCryptoCarteraPair(crypto: crypto, cartera: cartera)
                    }
                },
                set: { pair in
                    viewModel.selectedCryptoDetail = pair.map { ($0.crypto, $0.cartera) }
                }
            )) { pair in
                dependencies.makeCarteraCryptoDetailView(crypto: pair.crypto, cartera: pair.cartera)
            }
            .applyMovimientoSheets(
                viewModel: viewModel,
                dependencies: dependencies,
                showingCarteraMovimientos: $viewModel.showingCarteraMovimientos,
                showingEntradaForm: $viewModel.showingEntradaForm,
                showingSalidaForm: $viewModel.showingSalidaForm,
                showingEntreCarterasForm: $viewModel.showingEntreCarterasForm,
                showingSwapForm: $viewModel.showingSwapForm
            )
        #endif
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerWithMenu
            totalesCartera
            tablaCryptos
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var headerWithMenu: some View {
        HStack {
            #if os(iOS)
            NavigationLink(destination: dependencies.makeCarteraMovimientosView(
                cartera: viewModel.carteraDetail.cartera
            )) {
                Text(viewModel.carteraNombre)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
            }
            #else
            Button(action: { viewModel.showingCarteraMovimientos = true }) {
                Text(viewModel.carteraNombre)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
            }
            #endif
            
            Spacer()
            
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
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var totalesCartera: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Valor Total USD:")
                    .font(.caption)
                Text(viewModel.valorTotalUSD)
                    .bold()
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Ganancia Total:")
                    .font(.caption)
                Text(viewModel.gananciaTotal)
                    .foregroundColor(viewModel.isGananciaPositive ? .green : .red)
                    .bold()
            }
        }
        .padding(.bottom, 8)
    }
    
    private var tablaCryptos: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                headerTabla
                contenidoTabla
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var headerTabla: some View {
        HStack(spacing: 0) {
            Text("Crypto").frame(width: 80, alignment: .leading)
            Text("Ingresado").frame(width: 100, alignment: .trailing)
            Text("Vendido").frame(width: 100, alignment: .trailing)
            Text("Transfer.").frame(width: 100, alignment: .trailing)
            Text("Balance").frame(width: 100, alignment: .trailing)
            Text("USD Inv.").frame(width: 100, alignment: .trailing)
            Text("Valor USD").frame(width: 100, alignment: .trailing)
            Text("Ganancia").frame(width: 100, alignment: .trailing)
            Text("%").frame(width: 80, alignment: .trailing)
        }
        .font(.caption)
        .bold()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
    }
    
    private var contenidoTabla: some View {
        ForEach(viewModel.cryptoDetails) { detail in
            #if os(iOS)
            NavigationLink(destination: dependencies.makeCarteraCryptoDetailView(
                crypto: detail.crypto,
                cartera: viewModel.carteraDetail.cartera
            )) {
                cryptoRowContent(detail: detail)
            }
            .buttonStyle(.plain)
            #else
            Button(action: { viewModel.onCryptoSelected(detail) }) {
                cryptoRowContent(detail: detail)
            }
            .buttonStyle(.plain)
            #endif
        }
    }
    
    private func cryptoRowContent(detail: CryptoDetail) -> some View {
        HStack(spacing: 0) {
            Text(detail.crypto.simbolo)
                .frame(width: 80, alignment: .leading)
            Text(Format.crypto(detail.totalCryptoIngresado, symbol: detail.crypto.simbolo))
                .frame(width: 100, alignment: .trailing)
            Text(Format.crypto(detail.totalCryptoVendido, symbol: detail.crypto.simbolo))
                .frame(width: 100, alignment: .trailing)
            Text(Format.crypto(detail.totalCryptoTransferido, symbol: detail.crypto.simbolo))
                .frame(width: 100, alignment: .trailing)
                .foregroundColor(detail.totalCryptoTransferido >= 0 ? .green : .red)
            Text(Format.crypto(detail.balanceActual, symbol: detail.crypto.simbolo))
                .frame(width: 100, alignment: .trailing)
            Text(Format.usd(detail.totalInvertidoUSD))
                .frame(width: 100, alignment: .trailing)
            Text(Format.usd(detail.valorUSD))
                .frame(width: 100, alignment: .trailing)
            Text(Format.usd(detail.ganancia))
                .frame(width: 100, alignment: .trailing)
                .foregroundColor(detail.ganancia >= 0 ? .green : .red)
            Text(Format.percent(detail.porcentajeGanancia))
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(detail.porcentajeGanancia >= 0 ? .green : .red)
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - View Modifiers
private extension View {
    func applyMovimientoSheets(
        viewModel: CarteraDetailViewModel,
        dependencies: AppDependencyContainer,
        showingCarteraMovimientos: Binding<Bool>,
        showingEntradaForm: Binding<Bool>,
        showingSalidaForm: Binding<Bool>,
        showingEntreCarterasForm: Binding<Bool>,
        showingSwapForm: Binding<Bool>
    ) -> some View {
        #if os(iOS)
        self
            .fullScreenCover(isPresented: showingEntradaForm) {
                NavigationStack {
                    dependencies.makeMovimientoEntradaFormView()
                }
                .onDisappear { viewModel.updateData() }
            }
            .fullScreenCover(isPresented: showingSalidaForm) {
                NavigationStack {
                    dependencies.makeMovimientoSalidaFormView()
                }
                .onDisappear { viewModel.updateData() }
            }
            .fullScreenCover(isPresented: showingEntreCarterasForm) {
                NavigationStack {
                    dependencies.makeMovimientoEntreCarterasFormView()
                }
                .onDisappear { viewModel.updateData() }
            }
            .fullScreenCover(isPresented: showingSwapForm) {
                NavigationStack {
                    dependencies.makeMovimientoSwapFormView()
                }
                .onDisappear { viewModel.updateData() }
            }
        #else
        self
            .sheet(isPresented: showingCarteraMovimientos) {
                dependencies.makeCarteraMovimientosView(cartera: viewModel.carteraDetail.cartera)
                    .onDisappear {
                        viewModel.updateData()
                    }
            }
            .sheet(isPresented: showingEntradaForm) {
                NavigationStack {
                    dependencies.makeMovimientoEntradaFormView()
                }
                .adaptiveSheetFrame()
                .onDisappear { viewModel.updateData() }
            }
            .sheet(isPresented: showingSalidaForm) {
                NavigationStack {
                    dependencies.makeMovimientoSalidaFormView()
                }
                .adaptiveSheetFrame()
                .onDisappear { viewModel.updateData() }
            }
            .sheet(isPresented: showingEntreCarterasForm) {
                NavigationStack {
                    dependencies.makeMovimientoEntreCarterasFormView()
                }
                .adaptiveSheetFrame()
                .onDisappear { viewModel.updateData() }
            }
            .sheet(isPresented: showingSwapForm) {
                NavigationStack {
                    dependencies.makeMovimientoSwapFormView()
                }
                .adaptiveSheetFrame()
                .onDisappear { viewModel.updateData() }
            }
        #endif
    }
}
