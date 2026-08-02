import Foundation
import SwiftData
import Combine

@MainActor
final class MovimientoSwapViewModel: MovimientoViewModel {
    @Published var fecha = Date()
    @Published var selectedCryptoOrigen: Crypto?
    @Published var selectedCryptoDestino: Crypto?
    @Published var selectedCartera: Cartera?
    @Published var cantidadOrigen: Decimal = 0
    @Published var cantidadDestino: Decimal = 0
    @Published var precioUSDOrigen: Decimal = 0
    @Published var precioUSDDestino: Decimal = 0
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var uiState: MovimientoUIState = .idle

    private let modelContext: ModelContext
    /// Pierna de salida del swap (`.swapSalida`). La pierna de entrada se
    /// localiza por `groupId`.
    let movimiento: Movimiento?
    private var cancellables = Set<AnyCancellable>()

    var valorTotalOrigen: Decimal {
        cantidadOrigen * precioUSDOrigen
    }

    var valorTotalDestino: Decimal {
        cantidadDestino * precioUSDDestino
    }

     var cryptoDisponible: Decimal {
        guard let cartera = selectedCartera,
              let cryptoOrigen = selectedCryptoOrigen else { return 0 }

        if let movimiento = movimiento {
            return cartera.getCryptoDisponible(crypto: cryptoOrigen, movimientoActual: movimiento.cantidadOrigen)
        } else {
            return cartera.getCryptoDisponible(crypto: cryptoOrigen)
        }
    }

    var formIsValid: Bool {
        selectedCryptoDestino != nil &&
        selectedCryptoOrigen != nil &&
        selectedCartera != nil &&
        cantidadOrigen > 0 &&
        cantidadOrigen <= cryptoDisponible &&
        cantidadDestino > 0 &&
        precioUSDOrigen > 0 &&
        precioUSDDestino > 0 &&
        selectedCryptoOrigen != selectedCryptoDestino
    }

    init(modelContext: ModelContext, movimiento: Movimiento? = nil) {
        self.modelContext = modelContext
        self.movimiento = movimiento

        if let movimiento = movimiento {
            loadMovimiento(movimiento)
        }
        setupBindings()
    }

    private func setupBindings() {
        // Actualizar precio origen cuando cambia crypto
        $selectedCryptoOrigen
            .compactMap { $0 }
            .sink { [weak self] crypto in
                self?.precioUSDOrigen = crypto.precio
            }
            .store(in: &cancellables)

        // Actualizar precio destino cuando cambia crypto
        $selectedCryptoDestino
            .compactMap { $0 }
            .sink { [weak self] crypto in
                self?.precioUSDDestino = crypto.precio
            }
            .store(in: &cancellables)
    }

    private func loadMovimiento(_ movimiento: Movimiento) {
        selectedCartera = movimiento.cartera
        selectedCryptoOrigen = movimiento.cryptoOrigen
        selectedCryptoDestino = movimiento.cryptoDestino
        fecha = movimiento.fecha
        cantidadOrigen = movimiento.cantidadOrigen
        cantidadDestino = movimiento.cantidadDestino
        precioUSDOrigen = movimiento.precioUSDOrigen
        precioUSDDestino = movimiento.precioUSDDestino
    }

    /// Pierna de entrada del swap actual (si existe), localizada por `groupId`.
    private func piernaEntrada(_ movimiento: Movimiento) -> Movimiento? {
        guard let groupId = movimiento.groupId else { return nil }
        return (try? modelContext.fetch(
            FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.groupId == groupId && $0.tipoRaw == "swapEntrada" }
            )
        ))?.first
    }

    func adjustCantidadOrigen() {
        if cantidadOrigen > cryptoDisponible {
            cantidadOrigen = cryptoDisponible
        }
    }

    func setMaxCantidadOrigen() {
        cantidadOrigen = cryptoDisponible
    }

    func save() async throws {
        guard let cryptoOrigen = selectedCryptoOrigen,
              let cryptoDestino = selectedCryptoDestino else {
            throw MovimientoFormCommonError.missingCrypto
        }

        guard cryptoOrigen != cryptoDestino else {
            throw MovimientoFormCommonError.invalidAmount
        }

        guard let cartera = selectedCartera else {
            throw MovimientoFormCommonError.missingCartera
        }

        isLoading = true
        uiState = .loading

        do {
            if let existingMovimiento = movimiento {
                // Actualizar el par de movimientos existente
                let entrada = piernaEntrada(existingMovimiento)

                existingMovimiento.fecha = fecha
                existingMovimiento.cantidadOrigen = cantidadOrigen
                existingMovimiento.cantidadDestino = cantidadDestino
                existingMovimiento.precioUSDOrigen = precioUSDOrigen
                existingMovimiento.precioUSDDestino = precioUSDDestino
                existingMovimiento.cartera = cartera
                existingMovimiento.cryptoOrigen = cryptoOrigen
                existingMovimiento.cryptoDestino = cryptoDestino

                if let entrada = entrada {
                    entrada.fecha = fecha
                    entrada.cantidadOrigen = cantidadOrigen
                    entrada.cantidadDestino = cantidadDestino
                    entrada.precioUSDOrigen = precioUSDOrigen
                    entrada.precioUSDDestino = precioUSDDestino
                    entrada.cartera = cartera
                    entrada.cryptoOrigen = cryptoOrigen
                    entrada.cryptoDestino = cryptoDestino
                }
            } else {
                // Crear el par de movimientos (swapSalida + swapEntrada) con groupId compartido
                let par = Movimiento.swap(
                    fecha: fecha,
                    cantidadOrigen: cantidadOrigen,
                    cantidadDestino: cantidadDestino,
                    precioUSDOrigen: precioUSDOrigen,
                    precioUSDDestino: precioUSDDestino,
                    cartera: cartera,
                    cryptoOrigen: cryptoOrigen,
                    cryptoDestino: cryptoDestino
                )
                modelContext.insert(par.salida)
                modelContext.insert(par.entrada)
            }

            try modelContext.save()
            uiState = .success

        } catch {
            uiState = .error(error.localizedDescription)
            isLoading = false
            throw error
        }
        isLoading = false
    }

    func delete() async throws {
        guard let movimiento = movimiento else { return }

        isLoading = true
        uiState = .loading

        do {
            // Eliminar ambas piernas del par
            if let entrada = piernaEntrada(movimiento) {
                modelContext.delete(entrada)
            }
            modelContext.delete(movimiento)
            try modelContext.save()
            uiState = .success
        } catch {
            uiState = .error(error.localizedDescription)
            isLoading = false
            throw error
        }
        isLoading = false
    }
}
