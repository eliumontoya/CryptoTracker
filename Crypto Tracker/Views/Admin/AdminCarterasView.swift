import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdminCarterasView: View {
    @StateObject private var viewModel: AdminCarterasViewModel
    
    init(viewModel: AdminCarterasViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(viewModel.carteras) { cartera in
                    let calculos = viewModel.getCalculosCartera(cartera)
                    CarteraRowView(
                        cartera: cartera,
                        valorTotalUSD: calculos.valorTotal,
                        resumenCryptos: calculos.resumen,
                        gananciaPerdida: calculos.ganancia,
                        onToggleMain: { viewModel.toggleIsMain(cartera) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.showEditForm(for: cartera)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let cartera = viewModel.carteras[index]
                        if viewModel.canDeleteCartera(cartera) {
                            viewModel.deleteCartera(cartera)
                        } else {
                            viewModel.selectedCartera = cartera
                            viewModel.showingDeleteAlert = true
                        }
                    }
                }
            }
            .navigationTitle("Carteras")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showAddForm() }) {
                        Label("Agregar Cartera", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $viewModel.formState) { formState in
                NavigationStack {
                    CarteraFormView(
                        formState: formState,
                        portfolios: viewModel.portfolios
                    ) { nombre, simbolo, isMain, portfolio in
                        switch formState {
                        case .add:
                            viewModel.addCartera(nombre: nombre, simbolo: simbolo, isMain: isMain, portfolio: portfolio)
                        case .edit(let cartera):
                            viewModel.updateCartera(cartera, nombre: nombre, simbolo: simbolo, isMain: isMain, portfolio: portfolio)
                        }
                        viewModel.closeForm()
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .alert("¿Eliminar cartera?", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let cartera = viewModel.selectedCartera {
                        viewModel.deleteCartera(cartera)
                        viewModel.selectedCartera = nil
                    }
                }
            } message: {
                Text("Esta acción no se puede deshacer. ¿Está seguro de eliminar esta cartera?")
            }
        }
        .onDisappear {
            viewModel.clearCache()
        }
    }
}

struct CarteraRowView: View {
    let cartera: Cartera
    let valorTotalUSD: Decimal
    let resumenCryptos: String
    let gananciaPerdida: (ganancia: Decimal, esGanancia: Bool)
    let onToggleMain: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(cartera.nombre)
                    .font(.headline)
                Text("(\(cartera.simbolo))")
                    .foregroundColor(.secondary)
                if cartera.isMain {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                Spacer()
                Text(Format.usd(valorTotalUSD))
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            if let portfolioName = cartera.portfolio?.nombre {
                Text("Portfolio: \(portfolioName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !resumenCryptos.isEmpty {
                Text("Cryptos: \(resumenCryptos)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(gananciaPerdida.esGanancia ? "Ganancia:" : "Pérdida:")
                    .font(.caption)
                Text(Format.usd(gananciaPerdida.ganancia))
                    .font(.caption)
                    .foregroundColor(gananciaPerdida.esGanancia ? .green : .red)
                
                Spacer()
                
                Button(action: onToggleMain) {
                    Image(systemName: cartera.isMain ? "star.fill" : "star")
                        .foregroundColor(cartera.portfolio == nil ? .secondary : (cartera.isMain ? .yellow : .primary))
                }
                .buttonStyle(.plain)
                .disabled(cartera.portfolio == nil)
                .help(cartera.isMain ? "Unset main wallet" : "Set as main wallet")
            }
        }
        .padding(.vertical, 4)
    }
}

struct CarteraFormView: View {
    @Environment(\.dismiss) private var dismiss
    let formState: CarteraFormState
    let portfolios: [Portfolio]
    let onSave: (String, String, Bool, Portfolio?) -> Void

    @State private var nombre: String = ""
    @State private var simbolo: String = ""
    @State private var isMain: Bool = false
    @State private var selectedPortfolioID: UUID?

    private var selectedPortfolio: Portfolio? {
        portfolios.first { $0.id == selectedPortfolioID }
    }

    private var canBeMain: Bool {
        selectedPortfolio != nil
    }

    var title: String {
        switch formState {
        case .add:
            return "Nueva Cartera"
        case .edit:
            return "Editar Cartera"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Nombre", text: $nombre)
                .textFieldStyle(.roundedBorder)
            TextField("Símbolo", text: $simbolo)
                .textFieldStyle(.roundedBorder)

            Picker("Portfolio", selection: $selectedPortfolioID) {
                Text("None")
                    .tag(UUID?.none)
                ForEach(portfolios) { portfolio in
                    Text(portfolio.nombre)
                        .tag(UUID?.some(portfolio.id))
                }
            }
            .pickerStyle(.menu)

            Toggle("Main Wallet", isOn: $isMain)
                .disabled(!canBeMain)
                .onChange(of: selectedPortfolioID) { _ in
                    if !canBeMain {
                        isMain = false
                    }
                }

            Spacer()
        }
        .padding()
        .adaptiveSheetFrame(minWidth: 300, minHeight: 260)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    onSave(nombre, simbolo, isMain, selectedPortfolio)
                    dismiss()
                }
                .disabled(nombre.isEmpty || simbolo.isEmpty)
            }
        }
        .onAppear {
            if case .edit(let cartera) = formState {
                nombre = cartera.nombre
                simbolo = cartera.simbolo
                isMain = cartera.isMain
                selectedPortfolioID = cartera.portfolio?.id
            }
        }
    }
}
