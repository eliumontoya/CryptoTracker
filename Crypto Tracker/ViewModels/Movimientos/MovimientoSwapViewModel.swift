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
    private let swapUseCase: SwapMovementUseCaseProtocol
    private let editUseCase: EditMovementUseCaseProtocol
    private let deleteUseCase: DeleteMovementUseCaseProtocol
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
        selectedCryptoOrigen?.id != selectedCryptoDestino?.id
    }

    init(modelContext: ModelContext,
         movimiento: Movimiento? = nil,
         swapUseCase: SwapMovementUseCaseProtocol? = nil,
         editUseCase: EditMovementUseCaseProtocol? = nil,
         deleteUseCase: DeleteMovementUseCaseProtocol? = nil) {
        self.modelContext = modelContext
        let transactionRunner = ModelContextTransactionRunner(modelContext: modelContext)
        let holdingService = HoldingService()
        self.swapUseCase = swapUseCase ?? SwapMovementUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        self.editUseCase = editUseCase ?? EditMovementUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
        self.deleteUseCase = deleteUseCase ?? DeleteMovementUseCase(
            transactionRunner: transactionRunner,
            holdingService: holdingService
        )
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

        guard cryptoOrigen.id != cryptoDestino.id else {
            throw MovimientoFormCommonError.invalidAmount
        }

        guard let cartera = selectedCartera else {
            throw MovimientoFormCommonError.missingCartera
        }

        isLoading = true
        uiState = .loading

        do {
            if let existingMovimiento = movimiento {
                try await editUseCase.execute(EditSwapMovementInput(
                    salida: existingMovimiento,
                    updated: EditSwapMovementValues(
                        fecha: fecha,
                        cantidadOrigen: cantidadOrigen,
                        cantidadDestino: cantidadDestino,
                        precioUSDOrigen: precioUSDOrigen,
                        precioUSDDestino: precioUSDDestino,
                        cartera: cartera,
                        cryptoOrigen: cryptoOrigen,
                        cryptoDestino: cryptoDestino
                    )
                ))
            } else {
                _ = try await swapUseCase.execute(
                    SwapMovementInput(
                        fecha: fecha,
                        cantidadOrigen: cantidadOrigen,
                        cantidadDestino: cantidadDestino,
                        precioUSDOrigen: precioUSDOrigen,
                        precioUSDDestino: precioUSDDestino,
                        cartera: cartera,
                        cryptoOrigen: cryptoOrigen,
                        cryptoDestino: cryptoDestino
                    )
                )
            }
            uiState = .success

        } catch {
            uiState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            hasError = true
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
            try await deleteUseCase.delete(movimiento)
            uiState = .success
        } catch {
            uiState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            hasError = true
            isLoading = false
            throw error
        }
        isLoading = false
    }
}
