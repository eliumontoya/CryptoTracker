import SwiftUI
import SwiftData

struct MovimientosSearchFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MovimientosSearchFilterViewModel
    private let dependencies: AppDependencyContainer

    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: MovimientosSearchFilterViewModel(
            modelContext: dependencies.modelContext
        ))
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
        }
        #else
        content
        #endif
    }

    private var content: some View {
        VStack(spacing: 16) {
            headerView
            filterPanel
            resultsView
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
                dependencies.makeMovimientoSearchView(movimientoDetalle: movimientoDetalle)
            }
            .onDisappear {
                viewModel.cargarMovimientos()
            }
        }
        .accessibilityIdentifier("movements-search-view")
    }

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text(String(localized: "button_back"))
                }
            }
            Spacer()
            Text(String(localized: "movements_search_title"))
                .font(.title2)
                .bold()
            Spacer()
        }
    }

    private var filterPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "movements_search_placeholder"), text: $viewModel.filterState.searchText)
                    .textFieldStyle(.roundedBorder)
                if !viewModel.filterState.searchText.isEmpty {
                    Button(action: { viewModel.filterState.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("movements-search-clear-text")
                }
            }

            HStack(spacing: 12) {
                Picker(String(localized: "movements_filter_type"), selection: $viewModel.filterState.selectedTipo) {
                    Text(String(localized: "movements_filter_all_types"))
                        .tag(nil as TipoMovimientoDetalle?)
                    ForEach([TipoMovimientoDetalle.entrada, .salida, .transferencia, .swap], id: \.self) { tipo in
                        Text(tipo.title)
                            .tag(tipo as TipoMovimientoDetalle?)
                    }
                }
                .pickerStyle(.segmented)

                Picker(String(localized: "movements_filter_crypto"), selection: $viewModel.filterState.selectedCrypto) {
                    Text(String(localized: "movements_filter_all_cryptos"))
                        .tag(nil as Crypto?)
                    ForEach(cryptos) { crypto in
                        Text(crypto.simbolo)
                            .tag(crypto as Crypto?)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                DatePicker(
                    String(localized: "movements_filter_start_date"),
                    selection: optionalDateBinding($viewModel.filterState.startDate),
                    displayedComponents: .date
                )

                DatePicker(
                    String(localized: "movements_filter_end_date"),
                    selection: optionalDateBinding($viewModel.filterState.endDate),
                    displayedComponents: .date
                )
            }

            Button(action: { viewModel.clearFilters() }) {
                Label(String(localized: "movements_filter_clear"), systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("movements-search-clear-filters")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private var resultsView: some View {
        Group {
            if viewModel.isLoading {
                MovimientoLoadingView()
            } else if viewModel.filteredMovimientos.isEmpty {
                MovimientoEmptyView(message: String(localized: "movements_search_empty"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredMovimientos) { movimiento in
                            #if os(iOS)
                            NavigationLink(destination: dependencies.makeMovimientoSearchView(
                                movimientoDetalle: movimiento
                            )) {
                                MovimientoDetalleRowView(movimiento: movimiento, onTap: {})
                            }
                            .buttonStyle(.plain)
                            #else
                            MovimientoDetalleRowView(
                                movimiento: movimiento,
                                onTap: {
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
    }

    private func optionalDateBinding(_ value: Binding<Date?>) -> Binding<Date> {
        Binding<Date>(
            get: { value.wrappedValue ?? Date() },
            set: { newValue in
                value.wrappedValue = newValue
            }
        )
    }
}
