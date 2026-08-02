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
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol
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
         transactionRunner: TransactionRunner? = nil,
         holdingService: HoldingServiceProtocol? = nil) {
        self.modelContext = modelContext
        self.transactionRunner = transactionRunner ?? ModelContextTransactionRunner(modelContext: modelContext)
        self.holdingService = holdingService ?? HoldingService()
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

    /// Pierna de entrada de la transferencia actual (si existe), localizada por `groupId`.
    private func piernaEntrada(_ movimiento: Movimiento) -> Movimiento? {
        guard let groupId = movimiento.groupId else { return nil }
        return (try? modelContext.fetch(
            FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.groupId == groupId && $0.tipoRaw == "transferenciaEntrada" }
            )
        ))?.first
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
            try await transactionRunner.run { context in
                if let existingMovimiento = self.movimiento {
                    // Actualizar el par de movimientos existente: revertir los efectos
                    // anteriores sobre los holdings y aplicar los nuevos.
                    let previousSalida = self.holdingService.snapshot(of: existingMovimiento)
                    let entrada = self.piernaEntrada(existingMovimiento)
                    let previousEntrada = entrada.map { self.holdingService.snapshot(of: $0) }

                    existingMovimiento.fecha = fecha
                    existingMovimiento.cantidadCryptoSalida = cantidadCryptoSalida
                    existingMovimiento.cantidadCryptoEntrada = cantidadCryptoEntrada
                    existingMovimiento.cantidadCryptoComision = cantidadCryptoSalida - cantidadCryptoEntrada
                    existingMovimiento.carteraOrigen = carteraOrigen
                    existingMovimiento.carteraDestino = carteraDestino
                    existingMovimiento.cartera = carteraOrigen
                    existingMovimiento.crypto = crypto

                    if let entrada = entrada {
                        entrada.fecha = fecha
                        entrada.cantidadCryptoSalida = cantidadCryptoSalida
                        entrada.cantidadCryptoEntrada = cantidadCryptoEntrada
                        entrada.cantidadCryptoComision = cantidadCryptoSalida - cantidadCryptoEntrada
                        entrada.carteraOrigen = carteraOrigen
                        entrada.carteraDestino = carteraDestino
                        entrada.cartera = carteraDestino
                        entrada.crypto = crypto
                    }

                    try self.holdingService.updateHoldingForMovement(existingMovimiento, previous: previousSalida, in: context)
                    if let entrada = entrada, let previousEntrada = previousEntrada {
                        try self.holdingService.updateHoldingForMovement(entrada, previous: previousEntrada, in: context)
                    }
                } else {
                    // Crear el par de movimientos (salida + entrada) con groupId compartido
                    let par = Movimiento.transferencia(
                        fecha: fecha,
                        cantidadCryptoSalida: cantidadCryptoSalida,
                        cantidadCryptoEntrada: cantidadCryptoEntrada,
                        carteraOrigen: carteraOrigen,
                        carteraDestino: carteraDestino,
                        crypto: crypto
                    )
                    context.insert(par.salida)
                    context.insert(par.entrada)
                    try self.holdingService.updateHoldingForMovement(par.salida, in: context)
                    try self.holdingService.updateHoldingForMovement(par.entrada, in: context)
                }
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
            // Revertir holdings y eliminar ambas piernas del par en la misma transacción.
            try await transactionRunner.run { context in
                if let entrada = self.piernaEntrada(movimiento) {
                    try self.holdingService.deleteHoldingForMovement(entrada, in: context)
                    context.delete(entrada)
                }
                try self.holdingService.deleteHoldingForMovement(movimiento, in: context)
                context.delete(movimiento)
            }
            uiState = .success
        } catch {
            uiState = .error(error.localizedDescription)
            isLoading = false
            throw error
        }
        isLoading = false
    }
}
