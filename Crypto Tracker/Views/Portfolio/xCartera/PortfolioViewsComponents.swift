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
                Text(summary.valorTotalUSD.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            HStack {
                Text("Inversión: \(summary.totalInvertidoFIAT.formatted(.currency(code: "USD")))")
                Spacer()
                Text("Rentabilidad: \(summary.rentabilidadTotal.formatted(.number.precision(.fractionLength(2))))%")
                    .foregroundStyle(summary.rentabilidadTotal >= 0 ? .green : .red)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Vista Principal de Cartera
struct CarteraDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CarteraDetailViewModel
    
    init(carteraDetail: CarteraDetail, onUpdateData: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: CarteraDetailViewModel(
            carteraDetail: carteraDetail,
            onUpdateData: onUpdateData
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerWithMenu
            totalesCartera
            tablaCryptos
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
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
            CarteraCryptoDetailView(crypto: pair.crypto, cartera: pair.cartera)
        }
        .applyMovimientoSheets(
            viewModel: viewModel,
            context: modelContext,
            showingCarteraMovimientos: $viewModel.showingCarteraMovimientos,
            showingEntradaForm: $viewModel.showingEntradaForm,
            showingSalidaForm: $viewModel.showingSalidaForm,
            showingEntreCarterasForm: $viewModel.showingEntreCarterasForm,
            showingSwapForm: $viewModel.showingSwapForm
        )
    }
    
    private var headerWithMenu: some View {
        HStack {
            Button(action: { viewModel.showingCarteraMovimientos = true }) {
                Text(viewModel.carteraNombre)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
            }
            
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
            Button(action: { viewModel.onCryptoSelected(detail) }) {
                HStack(spacing: 0) {
                    Text(detail.crypto.simbolo)
                        .frame(width: 80, alignment: .leading)
                    Text(detail.totalCryptoIngresado.formatted())
                        .frame(width: 100, alignment: .trailing)
                    Text(detail.totalCryptoVendido.formatted())
                        .frame(width: 100, alignment: .trailing)
                    Text(detail.totalCryptoTransferido.formatted())
                        .frame(width: 100, alignment: .trailing)
                        .foregroundColor(detail.totalCryptoTransferido >= 0 ? .green : .red)
                    Text(detail.balanceActual.formatted())
                        .frame(width: 100, alignment: .trailing)
                    Text(detail.totalInvertidoUSD.formatted(.currency(code: "USD")))
                        .frame(width: 100, alignment: .trailing)
                    Text(detail.valorUSD.formatted(.currency(code: "USD")))
                        .frame(width: 100, alignment: .trailing)
                    Text(detail.ganancia.formatted(.currency(code: "USD")))
                        .frame(width: 100, alignment: .trailing)
                        .foregroundColor(detail.ganancia >= 0 ? .green : .red)
                    Text(detail.porcentajeGanancia.formatted(.number.precision(.fractionLength(2))) + "%")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(detail.porcentajeGanancia >= 0 ? .green : .red)
                }
            }
            .buttonStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    // ... resto del código de las vistas ...
}

// MARK: - View Modifiers
private extension View {
    func applyMovimientoSheets(
        viewModel: CarteraDetailViewModel,
        context: ModelContext,
        showingCarteraMovimientos: Binding<Bool>,
        showingEntradaForm: Binding<Bool>,
        showingSalidaForm: Binding<Bool>,
        showingEntreCarterasForm: Binding<Bool>,
        showingSwapForm: Binding<Bool>
    ) -> some View {
        self
            .sheet(isPresented: showingCarteraMovimientos) {
                CarteraMovimientosView(cartera: viewModel.carteraDetail.cartera)
                    .onDisappear {
                        viewModel.updateData()
                    }
            }
            .sheet(isPresented: showingEntradaForm) {
                NavigationStack {
                    MovimientoEntradaFormView(
                        viewModel: MovimientoEntradaViewModel(
                            modelContext: context,
                            movimiento: nil
                        )
                    )
                }
                .frame(minWidth: 500, minHeight: 700)
                .onDisappear { viewModel.updateData() }
            }
            .sheet(isPresented: showingSalidaForm) {
                NavigationStack {
                    MovimientoSalidaFormView(
                        viewModel: MovimientoSalidaViewModel(
                            modelContext: context,
                            movimiento: nil
                        )
                    )
                }
                .frame(minWidth: 500, minHeight: 700)
                .onDisappear { viewModel.updateData() }
            }
            .sheet(isPresented: showingEntreCarterasForm) {
                NavigationStack {
                    MovimientoEntreCarterasFormView(
                        viewModel: MovimientoEntreCarterasViewModel(
                            modelContext: context,
                            movimiento: nil
                        )
                    )
                }
                .frame(minWidth: 500, minHeight: 700)
                .onDisappear { viewModel.updateData() }
            }
            .sheet(isPresented: showingSwapForm) {
                NavigationStack {
                    MovimientoSwapFormView(
                        viewModel: MovimientoSwapViewModel(
                            modelContext: context,
                            movimiento: nil
                        )
                    )
                }
                .frame(minWidth: 500, minHeight: 700)
                .onDisappear { viewModel.updateData() }
            }
    }
}
