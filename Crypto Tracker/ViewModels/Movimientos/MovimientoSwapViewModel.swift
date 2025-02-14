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
    let movimiento: MovimientoSwap?
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
    
    init(modelContext: ModelContext, movimiento: MovimientoSwap? = nil) {
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
    
    private func loadMovimiento(_ movimiento: MovimientoSwap) {
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
              let cryptoDestino = selectedCryptoDestino,
              let cartera = selectedCartera,
              cryptoOrigen != cryptoDestino else {
            throw MovimientoFormError.invalidAmount
        }
        
        isLoading = true
        uiState = .loading
        
        do {
            if let existingMovimiento = movimiento {
                // Actualizar movimiento existente
                existingMovimiento.fecha = fecha
                existingMovimiento.cantidadOrigen = cantidadOrigen
                existingMovimiento.cantidadDestino = cantidadDestino
                existingMovimiento.precioUSDOrigen = precioUSDOrigen
                existingMovimiento.precioUSDDestino = precioUSDDestino
                existingMovimiento.cartera = cartera
                existingMovimiento.cryptoOrigen = cryptoOrigen
                existingMovimiento.cryptoDestino = cryptoDestino
            } else {
                // Crear nuevo movimiento
                let nuevoMovimiento = MovimientoSwap(
                    fecha: fecha,
                    cantidadOrigen: cantidadOrigen,
                    cantidadDestino: cantidadDestino,
                    precioUSDOrigen: precioUSDOrigen,
                    precioUSDDestino: precioUSDDestino,
                    cartera: cartera,
                    cryptoOrigen: cryptoOrigen,
                    cryptoDestino: cryptoDestino
                )
                modelContext.insert(nuevoMovimiento)
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
