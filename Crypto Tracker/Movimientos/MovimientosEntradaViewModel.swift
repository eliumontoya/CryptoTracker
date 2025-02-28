import Foundation
import Combine
import SwiftUI

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
    private(set) var movimiento: MovimientoIngreso?
    
    // Dependencias
    private let movimientoService: MovimientosEntradaServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(movimiento: MovimientoIngreso? = nil, movimientoService: MovimientosEntradaServiceProtocol) {
        self.movimiento = movimiento
        self.movimientoService = movimientoService
        
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
    
    func loadMovimiento(_ movimiento: MovimientoIngreso) {
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
            throw MovimientoFormError.missingCartera
        }
        
        isLoading = true
        uiState = .loading
        
        // Usar defer para asegurar que isLoading se establezca en false al salir
        defer {
            isLoading = false
        }
        
        do {
            if let existingMovimiento = movimiento {
                // Actualizar movimiento existente
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
                
                try movimientoService.save(movimiento: existingMovimiento)
            } else {
                // Crear nuevo movimiento
                let nuevoMovimiento = MovimientoIngreso(
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
                try movimientoService.insert(movimiento: nuevoMovimiento)
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
            try movimientoService.delete(movimiento: movimiento)
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
