import Foundation
import SwiftUI
import SwiftData

@MainActor
class AppDependencyContainer {
    // Contexto de modelo
    let modelContext: ModelContext
    
    // Servicios
    let movimientosEntradaService: MovimientosEntradaServiceProtocol
    
    // ViewModels
    let movimientoEntradaViewModel: MovimientoEntradaViewModel
    let movimientosEntradaListViewModel: MovimientosEntradaListViewModel
    let portfolioPorCryptosViewModel: PortfolioPorCryptosViewModel
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Inicializar servicios
        self.movimientosEntradaService = MovimientosEntradaService(modelContext: modelContext)
        
        // Inicializar ViewModels individuales
        self.movimientoEntradaViewModel = MovimientoEntradaViewModel(
            movimientoService: movimientosEntradaService
        )
        
        // Inicializar ViewModel de lista
        self.movimientosEntradaListViewModel = MovimientosEntradaListViewModel(
            movimientoService: movimientosEntradaService
        )
        
        // Otros ViewModels
        self.portfolioPorCryptosViewModel = PortfolioPorCryptosViewModel(
            modelContext: modelContext,
            movimientoService: movimientosEntradaService
        )
    }
    
    // Métodos factory para crear vistas con sus dependencias
    func makeMovimientosEntradaView() -> some View {
        MovimientosEntradaView(viewModel: movimientosEntradaListViewModel)
    }
    
    func makeMovimientoEntradaFormView(movimiento: MovimientoIngreso? = nil) -> some View {
        // Si se proporciona un movimiento, creamos un ViewModel específico para él
        if let movimiento = movimiento {
            let viewModel = MovimientoEntradaViewModel(
                movimiento: movimiento,
                movimientoService: movimientosEntradaService
            )
            return MovimientoEntradaFormView(viewModel: viewModel)
        } else {
            // Para nuevos movimientos, usamos el ViewModel compartido
            // pero reseteando su estado
            movimientoEntradaViewModel.unloadMovimiento()
            return MovimientoEntradaFormView(viewModel: movimientoEntradaViewModel)
        }
    }
    
    // Otros métodos factory para otras vistas...
}
