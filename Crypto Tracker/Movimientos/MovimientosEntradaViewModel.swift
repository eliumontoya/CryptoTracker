import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class MovimientoEntradaViewModel: ObservableObject, MovimientoViewModel {
    // Propiedades del formulario
    @Published var fecha = Date()
    @Published var selectedCrypto: Crypto?
    @Published var selectedCartera: Cartera?
    @Published var cantidadCrypto: Decimal = 0
    @Published var precioUSD: Decimal = 0
    @Published var valorTotalUSD: Decimal = 0
    @Published var usaFiatAlterno = false
    @Published var selectedFiatAlterno: FIAT?
    @Published var valorTotalFiatAlterno: Decimal = 0
    
    // Estado de UI
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var uiState: MovimientoUIState = .idle
    
    // Modelo
    private(set) var movimiento: Movimiento?
    
    // Dependencias
    private let modelContext: ModelContext
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
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
    
    // MARK: - Public API
    
    var formIsValid: Bool {
        return selectedCrypto != nil &&
                selectedCartera != nil &&
                cantidadCrypto > 0 &&
                precioUSD > 0 &&
                (!usaFiatAlterno || (selectedFiatAlterno != nil && precioFiatAlterno > 0))
    }
    
    var precioFiatAlterno: Decimal {
        guard cantidadCrypto > 0 else { return 0 }
        return valorTotalFiatAlterno / cantidadCrypto
    }
    
    func loadMovimiento(_ movimiento: Movimiento) {
        print("Cargando movimiento: \(movimiento.id)")
        self.movimiento = movimiento
        
        // Cargar datos del movimiento al ViewModel
        self.selectedCrypto = movimiento.crypto
        self.selectedCartera = movimiento.cartera
        self.fecha = movimiento.fecha
        self.cantidadCrypto = movimiento.cantidadCrypto
        self.precioUSD = movimiento.precioUSD
        self.valorTotalUSD = movimiento.valorTotalUSD
        self.usaFiatAlterno = movimiento.usaFiatAlterno
        self.selectedFiatAlterno = movimiento.fiatAlterno
        self.valorTotalFiatAlterno = movimiento.valorTotalFiatAlterno ?? 0
        
        // Notificar a SwiftUI que debe actualizar la vista
        objectWillChange.send()
        
        print("Movimiento cargado: \(movimiento.id) - Crypto: \(String(describing: selectedCrypto?.simbolo))")
    }
    
    func unloadMovimiento() {
        movimiento = nil
        
        // Reiniciar el formulario
        fecha = Date()
        selectedCrypto = nil
        selectedCartera = nil
        cantidadCrypto = 0
        precioUSD = 0
        valorTotalUSD = 0
        usaFiatAlterno = false
        selectedFiatAlterno = nil
        valorTotalFiatAlterno = 0
        uiState = .idle
    }
    
    func calcularPrecioUSD() {
        guard usaFiatAlterno, let fiat = selectedFiatAlterno else { return }
        
        // Convertir de FIAT alterno a USD
        valorTotalUSD = valorTotalFiatAlterno * (1 / fiat.precioUSD)
        
        // Calcular el precio unitario
        if cantidadCrypto > 0 {
            precioUSD = valorTotalUSD / cantidadCrypto
        }
    }
    
    func onCantidadCryptoChange() {
        if usaFiatAlterno {
            calcularPrecioUSD()
        } else {
            valorTotalUSD = cantidadCrypto * precioUSD
        }
    }
    
    // MARK: - MovimientoViewModel Protocol
    
    func save() async throws {
        guard formIsValid else {
            throw validateForm()
        }
        
        guard let crypto = selectedCrypto,
              let cartera = selectedCartera else {
            throw MovimientoFormCommonError.missingCartera
        }
        
        isLoading = true
        uiState = .loading
        
        // Usar defer para asegurar que isLoading se establezca en false al salir
        defer {
            isLoading = false
        }
        
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
                let nuevoMovimiento = Movimiento.entrada(
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
                self.movimiento = nuevoMovimiento
            }
            
            uiState = .success
        } catch {
            uiState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            hasError = true
            throw error
        }
    }
    
    func delete() async throws {
        guard let movimiento = movimiento else {
            return
        }
        
        isLoading = true
        uiState = .loading
        
        // Usar defer para asegurar que isLoading se establezca en false al salir
        defer {
            isLoading = false
        }
        
        do {
            // Revertir holding y borrar el movimiento en la misma transacción.
            try await transactionRunner.run { context in
                try holdingService.deleteHoldingForMovement(movimiento, in: context)
                context.delete(movimiento)
            }
            unloadMovimiento()
            uiState = .success
        } catch {
            uiState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            hasError = true
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Actualizar valorTotalUSD cuando cambia precioUSD o cantidadCrypto
        Publishers.CombineLatest($cantidadCrypto, $precioUSD)
            .dropFirst()
            .filter { [weak self] _ in
                guard let self = self else { return false }
                return !self.usaFiatAlterno
            }
            .sink { [weak self] cantidad, precio in
                self?.valorTotalUSD = cantidad * precio
            }
            .store(in: &cancellables)
        
        // Manejar cambios en usaFiatAlterno
        $usaFiatAlterno
            .dropFirst()
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
        
        // Monitorear cambios en el estado de UI
        $uiState
            .sink { [weak self] state in
                if case .error(let message) = state {
                    self?.hasError = true
                    self?.errorMessage = message
                } else {
                    self?.hasError = false
                    self?.errorMessage = ""
                }
            }
            .store(in: &cancellables)
    }
    
    private func validateForm() -> MovimientoFormCommonError {
        if selectedCrypto == nil {
            return .missingCrypto
        }
        
        if selectedCartera == nil {
            return .missingCartera
        }
        
        if cantidadCrypto <= 0 {
            return .invalidAmount
        }
        
        if precioUSD <= 0 {
            return .invalidPrice
        }
        
        if usaFiatAlterno {
            if selectedFiatAlterno == nil || valorTotalFiatAlterno <= 0 {
                return .invalidAmount
            }
        }
        
        return .saveFailed("Error de validación desconocido")
    }
}
