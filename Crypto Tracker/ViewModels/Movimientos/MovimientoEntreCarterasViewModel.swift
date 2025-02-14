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
    let movimiento: MovimientoEntreCarteras?
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
    
    init(modelContext: ModelContext, movimiento: MovimientoEntreCarteras? = nil) {
        self.modelContext = modelContext
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
    
    private func loadMovimiento(_ movimiento: MovimientoEntreCarteras) {
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
        adjustCantidades()
    }
    
    func setMaxCantidadEntrada() {
        cantidadCryptoEntrada = cantidadCryptoSalida
    }
    
    func save() async throws {
        guard let crypto = selectedCrypto,
              let carteraOrigen = selectedCarteraOrigen,
              let carteraDestino = selectedCarteraDestino else {
            throw MovimientoFormError.missingCartera
        }
        
        if carteraOrigen.id == carteraDestino.id {
            throw MovimientoFormError.sameCartera
        }
        
        isLoading = true
        uiState = .loading
        
        do {
            if let existingMovimiento = movimiento {
                // Actualizar movimiento existente
                existingMovimiento.fecha = fecha
                existingMovimiento.cantidadCryptoSalida = cantidadCryptoSalida
                existingMovimiento.cantidadCryptoEntrada = cantidadCryptoEntrada
                existingMovimiento.carteraOrigen = carteraOrigen
                existingMovimiento.carteraDestino = carteraDestino
                existingMovimiento.crypto = crypto
            } else {
                // Crear nuevo movimiento
                let nuevoMovimiento = MovimientoEntreCarteras(
                    fecha: fecha,
                    cantidadCryptoSalida: cantidadCryptoSalida,
                    cantidadCryptoEntrada: cantidadCryptoEntrada,
                    carteraOrigen: carteraOrigen,
                    carteraDestino: carteraDestino,
                    crypto: crypto
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
