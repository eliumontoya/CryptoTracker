import Foundation
import SwiftData
import Combine

// MARK: - Filter State

/// UI state for the movements search filter. A nil option means "all".
struct MovimientosFilterState {
    var searchText: String = ""
    var selectedTipo: TipoMovimientoDetalle?
    var selectedCrypto: Crypto?
    var startDate: Date?
    var endDate: Date?
}

// MARK: - ViewModel

@MainActor
final class MovimientosSearchFilterViewModel: ObservableObject {
    @Published var filterState = MovimientosFilterState()
    @Published var movimientos: [MovimientoDetalle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMovimientoDetalle: MovimientoDetalle?

    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        bindFilters()
    }

    // MARK: - Public API

    func cargarMovimientos() {
        isLoading = true
        defer { isLoading = false }

        do {
            let raw = try modelContext.fetch(
                FetchDescriptor<Movimiento>(sortBy: [SortDescriptor(\.fecha, order: .reverse)])
            )
            movimientos = raw.compactMap(mapToDetalle)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearFilters() {
        filterState = MovimientosFilterState()
    }

    var filteredMovimientos: [MovimientoDetalle] {
        movimientos.filter(passesFilters)
    }

    // MARK: - Filtering

    private func bindFilters() {
        $filterState
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                // No need to reload from the store; filtering is in-memory.
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func passesFilters(_ movimiento: MovimientoDetalle) -> Bool {
        let state = filterState

        if let selectedTipo = state.selectedTipo, movimiento.tipo != selectedTipo {
            return false
        }

        if let selectedCrypto = state.selectedCrypto {
            let matches = movimiento.cryptoOrigen == selectedCrypto.simbolo
                || movimiento.cryptoDestino == selectedCrypto.simbolo
            if !matches { return false }
        }

        if let startDate = state.startDate, movimiento.fecha < startDate {
            return false
        }

        if let endDate = state.endDate, movimiento.fecha > endDate {
            return false
        }

        if !state.searchText.isEmpty {
            let term = state.searchText.lowercased()
            let text = "\(movimiento.carteraOrigen ?? "") \(movimiento.carteraDestino ?? "") \(movimiento.cryptoOrigen) \(movimiento.cryptoDestino) \(movimiento.tipo.title)"
                .lowercased()
            if !text.contains(term) { return false }
        }

        return true
    }

    // MARK: - Mapping

    private func mapToDetalle(_ movimiento: Movimiento) -> MovimientoDetalle? {
        switch movimiento.tipo {
        case .entrada:
            guard let crypto = movimiento.crypto,
                  let cartera = movimiento.cartera else { return nil }
            return MovimientoDetalle(
                id: movimiento.id,
                fecha: movimiento.fecha,
                tipo: .entrada,
                carteraOrigen: nil,
                carteraDestino: cartera.nombre,
                cantidadOrigen: movimiento.cantidadCrypto,
                cantidadDestino: movimiento.cantidadCrypto,
                cryptoOrigen: crypto.simbolo,
                cryptoDestino: crypto.simbolo,
                valorUSD: movimiento.valorTotalUSD
            )

        case .salida:
            guard let crypto = movimiento.crypto,
                  let cartera = movimiento.cartera else { return nil }
            return MovimientoDetalle(
                id: movimiento.id,
                fecha: movimiento.fecha,
                tipo: .salida,
                carteraOrigen: cartera.nombre,
                carteraDestino: nil,
                cantidadOrigen: movimiento.cantidadCrypto,
                cantidadDestino: movimiento.cantidadCrypto,
                cryptoOrigen: crypto.simbolo,
                cryptoDestino: crypto.simbolo,
                valorUSD: movimiento.valorTotalUSD
            )

        case .transferenciaSalida:
            guard let crypto = movimiento.crypto,
                  let carteraOrigen = movimiento.carteraOrigen,
                  let carteraDestino = movimiento.carteraDestino else { return nil }
            return MovimientoDetalle(
                id: movimiento.id,
                fecha: movimiento.fecha,
                tipo: .transferencia,
                carteraOrigen: carteraOrigen.nombre,
                carteraDestino: carteraDestino.nombre,
                cantidadOrigen: movimiento.cantidadCryptoSalida,
                cantidadDestino: movimiento.cantidadCryptoEntrada,
                cryptoOrigen: crypto.simbolo,
                cryptoDestino: crypto.simbolo,
                valorUSD: movimiento.cantidadCryptoSalida * movimiento.precioUSD
            )

        case .swapSalida:
            guard let cryptoOrigen = movimiento.cryptoOrigen,
                  let cryptoDestino = movimiento.cryptoDestino,
                  let cartera = movimiento.cartera else { return nil }
            return MovimientoDetalle(
                id: movimiento.id,
                fecha: movimiento.fecha,
                tipo: .swap,
                carteraOrigen: cartera.nombre,
                carteraDestino: cartera.nombre,
                cantidadOrigen: movimiento.cantidadOrigen,
                cantidadDestino: movimiento.cantidadDestino,
                cryptoOrigen: cryptoOrigen.simbolo,
                cryptoDestino: cryptoDestino.simbolo,
                valorUSD: movimiento.cantidadOrigen * movimiento.precioUSDOrigen
            )

        case .transferenciaEntrada, .swapEntrada, .ajuste, .comision:
            // The "salida" leg already represents the logical operation; skip duplicates.
            return nil
        }
    }
}
