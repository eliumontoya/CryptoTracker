import Foundation
import SwiftData
import Combine

@MainActor
final class MovimientoEntreCarterasViewModel: MovimientoViewModel {
    @Published var fecha = Date()
    @Published var selectedCrypto: Crypto?
    @Published var selectedCarteraOrigen: Cartera?
    @Published var selectedCarteraDestino: Cartera?
    @Published var cantidadCryptoSalida: Decimal = 0
    @Published var cantidadCryptoEntrada: Decimal = 0
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var uiState: MovimientoUIState = .idle

    private let modelContext: ModelContext
    private let moveBetweenWalletsUseCase: MoveBetweenWalletsUseCaseProtocol
    private let editUseCase: EditMovementUseCaseProtocol
    private let deleteUseCase: DeleteMovementUseCaseProtocol
    /// Pierna de salida de la transferencia (`.transferenciaSalida`). La pierna de
    /// entrada se localiza por `groupId`.
    let movimiento: Movimiento?
    private var cancellables = Set<AnyCancellable>()

    var comision: Decimal {
        cantidadCryptoSalida - cantidadCryptoEntrada
    }

     var cryptoDisponible: Decimal {
        guard let cartera = selectedCarteraOrigen,
              let crypto = selectedCrypto else { return 0 }

        if let movimiento = movimiento {
            return cartera.getCryptoDisponible(crypto: crypto, movimientoActual: movimiento.cantidadCryptoSalida)
        } else {
            return cartera.getCryptoDisponible(crypto: crypto)
        }
    }

    var formIsValid: Bool {
        selectedCrypto != nil &&
        selectedCarteraOrigen != nil &&
        selectedCarteraDestino != nil &&
        selectedCarteraOrigen?.id != selectedCarteraDestino?.id &&
        cantidadCryptoSalida > 0 &&
        cantidadCryptoEntrada > 0 &&
        cantidadCryptoEntrada <= cantidadCryptoSalida &&
        cantidadCryptoSalida <= cryptoDisponible
    }

    init(modelContext: ModelContext,
         movimiento: Movimiento? = nil,
         moveBetweenWalletsUseCase: MoveBetweenWalletsUseCaseProtocol? = nil,
         editUseCase: EditMovementUseCaseProtocol? = nil,
         deleteUseCase: DeleteMovementUseCaseProtocol? = nil) {
        self.modelContext = modelContext
        let transactionRunner = ModelContextTransactionRunner(modelContext: modelContext)
        let holdingService = HoldingService()
        self.moveBetweenWalletsUseCase = moveBetweenWalletsUseCase ?? MoveBetweenWalletsUseCase(
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

        setupBindings()
        if let movimiento = movimiento {
            loadMovimiento(movimiento)
        }
    }

    private func setupBindings() {
        // Actualizar entrada cuando cambia salida
        $cantidadCryptoSalida
            .sink { [weak self] cantidad in
                guard let self = self else { return }
                if self.cantidadCryptoEntrada > cantidad {
                    self.cantidadCryptoEntrada = cantidad
                }
            }
            .store(in: &cancellables)
    }

    private func loadMovimiento(_ movimiento: Movimiento) {
        selectedCrypto = movimiento.crypto
        selectedCarteraOrigen = movimiento.carteraOrigen
        selectedCarteraDestino = movimiento.carteraDestino
        fecha = movimiento.fecha
        cantidadCryptoSalida = movimiento.cantidadCryptoSalida
        cantidadCryptoEntrada = movimiento.cantidadCryptoEntrada
    }

    func adjustCantidades() {
        if cantidadCryptoSalida > cryptoDisponible {
            cantidadCryptoSalida = cryptoDisponible
        }
        if cantidadCryptoEntrada > cantidadCryptoSalida {
            cantidadCryptoEntrada = cantidadCryptoSalida
        }
    }

    func setMaxCantidadSalida() {
        cantidadCryptoSalida = cryptoDisponible
        cantidadCryptoEntrada = cantidadCryptoSalida
        adjustCantidades()
    }

    func setMaxCantidadEntrada() {
        cantidadCryptoEntrada = cantidadCryptoSalida
    }

    func save() async throws {
        guard let crypto = selectedCrypto else {
            throw MovimientoFormCommonError.missingCrypto
        }

        guard let carteraOrigen = selectedCarteraOrigen,
              let carteraDestino = selectedCarteraDestino else {
            throw MovimientoFormCommonError.missingCartera
        }

        if carteraOrigen.id == carteraDestino.id {
            throw MovimientoFormCommonError.sameCartera
        }

        isLoading = true
        uiState = .loading

        do {
            if let existingMovimiento = movimiento {
                try await editUseCase.execute(EditTransferMovementInput(
                    salida: existingMovimiento,
                    updated: EditTransferMovementValues(
                        fecha: fecha,
                        cantidadCryptoSalida: cantidadCryptoSalida,
                        cantidadCryptoEntrada: cantidadCryptoEntrada,
                        crypto: crypto,
                        carteraOrigen: carteraOrigen,
                        carteraDestino: carteraDestino
                    )
                ))
            } else {
                _ = try await moveBetweenWalletsUseCase.execute(
                    MoveBetweenWalletsInput(
                        fecha: fecha,
                        cantidadCryptoSalida: cantidadCryptoSalida,
                        cantidadCryptoEntrada: cantidadCryptoEntrada,
                        precioUSD: crypto.precio,
                        carteraOrigen: carteraOrigen,
                        carteraDestino: carteraDestino,
                        crypto: crypto
                    )
                )
            }
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
            try await deleteUseCase.delete(movimiento)
            uiState = .success
        } catch {
            uiState = .error(error.localizedDescription)
            isLoading = false
            throw error
        }
        isLoading = false
    }
}
