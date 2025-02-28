import Foundation
import SwiftData
import Combine

@MainActor
final class MovimientosEntradaListViewModel: ObservableObject {
    // Estado de UI
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var uiState: MovimientoUIState = .idle
    
    // ViewModel para manejar el formulario de movimientos
    @Published var entradaViewModel: MovimientoEntradaViewModel
    
    // Dependencias
    private let movimientoService: MovimientosEntradaServiceProtocol
    
    // Cancellables para gestionar subscripciones
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(movimientoService: MovimientosEntradaServiceProtocol) {
        self.movimientoService = movimientoService
        // Inicializar el entradaViewModel primero
        self.entradaViewModel = MovimientoEntradaViewModel(movimientoService: movimientoService)
        
        // Ahora que todas las propiedades están inicializadas, podemos llamar a setupBindings
        setupBindings()
    }
    
    // MARK: - Public methods
    
    func prepareForAdd() {
        entradaViewModel.unloadMovimiento()
    }
    
    func prepareForEdit(movimiento: MovimientoIngreso) {
        entradaViewModel.loadMovimiento(movimiento)
    }
    
    func refreshData() {
        // Esta función se llama cuando un sheet se cierra
        // No necesitamos hacer nada específico aquí porque
        // SwiftData actualiza automáticamente las consultas @Query
    }
    
    func deleteMovimientos(at offsets: IndexSet, from movimientos: [MovimientoIngreso]) async throws {
        isLoading = true
        uiState = .loading
        
        // Usar defer para asegurar que isLoading se establezca en false al salir
        defer {
            isLoading = false
        }
        
        do {
            for index in offsets {
                try await Task.sleep(nanoseconds: 100_000_000) // pequeña pausa para evitar conflictos
                try movimientoService.delete(movimiento: movimientos[index])
            }
            
            uiState = .success
        } catch {
            uiState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            hasError = true
            throw error
        }
    }
    
    // MARK: - Private methods
    
    private func setupBindings() {
        // Observar cambios en el ViewModel de entrada
        entradaViewModel.$uiState
            .sink { [weak self] state in
                if case .error(let message) = state {
                    self?.errorMessage = message
                    self?.hasError = true
                }
            }
            .store(in: &cancellables)
        
        // Observar cambios en el estado de UI
        $uiState
            .sink { [weak self] state in
                if case .error(let message) = state {
                    self?.hasError = true
                    self?.errorMessage = message
                } else if case .success = state {
                    self?.hasError = false
                    self?.errorMessage = ""
                }
            }
            .store(in: &cancellables)
    }
}
