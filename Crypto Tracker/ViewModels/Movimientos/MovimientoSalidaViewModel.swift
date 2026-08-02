import Foundation
import SwiftData
import Combine

@MainActor
final class MovimientoSalidaViewModel: MovimientoViewModel {
    @Published var fecha = Date()
    @Published var selectedCrypto: Crypto?
    @Published var selectedCartera: Cartera?
    @Published var cantidadCrypto: Decimal = 0
    @Published var precioUSD: Decimal = 0
    @Published var valorTotalUSD: Decimal = 0
    @Published var usaFiatAlterno = false
    @Published var selectedFiatAlterno: FIAT?
    @Published var valorTotalFiatAlterno: Decimal = 0
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var uiState: MovimientoUIState = .idle
    
    private let modelContext: ModelContext
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol
    let movimiento: Movimiento?
    private var cancellables = Set<AnyCancellable>()
    
    private var cryptoDisponible: Decimal {
        guard let cartera = selectedCartera,
              let crypto = selectedCrypto else { return 0 }
        
        if let movimiento = movimiento {
            return cartera.getCryptoDisponible(crypto: crypto, movimientoActual: movimiento.cantidadCrypto)
        } else {
            return cartera.getCryptoDisponible(crypto: crypto)
        }
    }
    
    var formIsValid: Bool {
        guard let cartera = selectedCartera,
              let crypto = selectedCrypto else { return false }
        
        return cantidadCrypto > 0 &&
               cantidadCrypto <= cryptoDisponible &&
               precioUSD > 0 &&
               (!usaFiatAlterno || (selectedFiatAlterno != nil && valorTotalFiatAlterno > 0))
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
    
    private var precioFiatAlterno: Decimal {
        guard cantidadCrypto > 0 else { return 0 }
        return valorTotalFiatAlterno / cantidadCrypto
    }
    
    private func setupBindings() {
        // Actualizar valor total USD cuando cambia cantidad o precio
        Publishers.CombineLatest($cantidadCrypto, $precioUSD)
            .sink { [weak self] cantidad, precio in
                guard let self = self, !self.usaFiatAlterno else { return }
                self.valorTotalUSD = cantidad * precio
            }
            .store(in: &cancellables)
        
        // Manejar cambios en FIAT alterno
        $usaFiatAlterno
            .sink { [weak self] usaFiat in
                guard let self = self else { return }
                if usaFiat {
                    if let fiat = self.selectedFiatAlterno {
                        self.valorTotalFiatAlterno = self.valorTotalUSD * fiat.precioUSD
                    }
                } else {
                    self.selectedFiatAlterno = nil
                    self.valorTotalFiatAlterno = 0
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadMovimiento(_ movimiento: Movimiento) {
        selectedCrypto = movimiento.crypto
        selectedCartera = movimiento.cartera
        fecha = movimiento.fecha
        cantidadCrypto = movimiento.cantidadCrypto
        precioUSD = movimiento.precioUSD
        valorTotalUSD = movimiento.valorTotalUSD
        usaFiatAlterno = movimiento.usaFiatAlterno
        selectedFiatAlterno = movimiento.fiatAlterno
        valorTotalFiatAlterno = movimiento.valorTotalFiatAlterno ?? 0
    }
    
    func calcularPrecioUSD() {
        guard usaFiatAlterno, let fiat = selectedFiatAlterno else { return }
        valorTotalUSD = valorTotalFiatAlterno * (1 / fiat.precioUSD)
        if cantidadCrypto > 0 {
            precioUSD = valorTotalUSD / cantidadCrypto
        }
    }
    
    func onCantidadCryptoChange() {
        if cantidadCrypto > cryptoDisponible {
            cantidadCrypto = cryptoDisponible
        }
        
        if usaFiatAlterno {
            calcularPrecioUSD()
        } else {
            valorTotalUSD = cantidadCrypto * precioUSD
        }
    }
    
    func save() async throws {
        guard let crypto = selectedCrypto,
              let cartera = selectedCartera else {
            throw MovimientoFormCommonError.missingCartera
        }
        
        isLoading = true
        uiState = .loading
        
        do {
            if let existingMovimiento = movimiento {
                // Actualizar movimiento existente: revertir el efecto anterior sobre
                // el holding y aplicar el nuevo, todo en una sola transacción.
                let previous = holdingService.snapshot(of: existingMovimiento)
                try await transactionRunner.run { context in
                    existingMovimiento.fecha = fecha
                    existingMovimiento.cantidadCrypto = cantidadCrypto
                    existingMovimiento.precioUSD = precioUSD
                    existingMovimiento.valorTotalUSD = valorTotalUSD
                    existingMovimiento.usaFiatAlterno = usaFiatAlterno
                    existingMovimiento.precioFiatAlterno = usaFiatAlterno ? precioFiatAlterno : nil
                    existingMovimiento.valorTotalFiatAlterno = usaFiatAlterno ? valorTotalFiatAlterno : nil
                    existingMovimiento.cartera = cartera
                    existingMovimiento.crypto = crypto
                    existingMovimiento.fiatAlterno = usaFiatAlterno ? selectedFiatAlterno : nil
                    
                    try holdingService.updateHoldingForMovement(existingMovimiento, previous: previous, in: context)
                }
            } else {
                // Crear nuevo movimiento + actualizar holding en la misma transacción.
                let nuevoMovimiento = Movimiento.salida(
                    fecha: fecha,
                    cantidadCrypto: cantidadCrypto,
                    precioUSD: precioUSD,
                    usaFiatAlterno: usaFiatAlterno,
                    precioFiatAlterno: usaFiatAlterno ? precioFiatAlterno : nil,
                    valorTotalFiatAlterno: usaFiatAlterno ? valorTotalFiatAlterno : nil,
                    cartera: cartera,
                    crypto: crypto,
                    fiatAlterno: usaFiatAlterno ? selectedFiatAlterno : nil
                )
                try await transactionRunner.run { context in
                    context.insert(nuevoMovimiento)
                    try holdingService.updateHoldingForMovement(nuevoMovimiento, in: context)
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
            // Revertir holding y borrar el movimiento en la misma transacción.
            try await transactionRunner.run { context in
                try holdingService.deleteHoldingForMovement(movimiento, in: context)
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
