// MovimientoForms.swift
import SwiftUI
import SwiftData

// MARK: - Vista de Edición General


// MARK: - Vista para buscar el movimiento correcto
enum EditMovementMode: Equatable {
    case entrada(MovimientoIngreso)
    case salida(MovimientoEgreso)
    case entreCarteras(MovimientoEntreCarteras)
    case swap(MovimientoSwap)
}

// MARK: - Vista para buscar el movimiento correcto
struct MovimientoSearchView: View {
    @StateObject private var movimientoEntradaViewModel: MovimientoEntradaViewModel
    let movimientoDetalle: MovimientoDetalle
    let modelContext: ModelContext

    init(movimientoDetalle: MovimientoDetalle, modelContext: ModelContext) {
        self.movimientoDetalle = movimientoDetalle
        self.modelContext = modelContext
        let service = MovimientosEntradaService(modelContext: modelContext)
        _movimientoEntradaViewModel = StateObject(wrappedValue:
            MovimientoEntradaViewModel(movimiento: nil, movimientoService: service))
    }
    
    @Query private var movimientosIngreso: [MovimientoIngreso]
    @Query private var movimientosEgreso: [MovimientoEgreso]
    @Query private var movimientosEntreCarteras: [MovimientoEntreCarteras]
    @Query private var movimientosSwap: [MovimientoSwap]
    
    var body: some View {
        NavigationStack {
            if let mode = findEditMode() {
                EditMovimientoView(mode: mode, movimientoEntradaViewModel: self.movimientoEntradaViewModel)
            } else {
                ContentUnavailableView(
                    "Movimiento no encontrado",
                    systemImage: "exclamationmark.triangle",
                    description: Text("No se pudo encontrar el detalle del movimiento seleccionado.")
                )
            }
        }
    }
    
    private func findEditMode() -> EditMovementMode? {
        switch movimientoDetalle.tipo {
        case .entrada:
            if let movimiento = movimientosIngreso.first(where: { $0.id == movimientoDetalle.id }) {
                print("Encontrado movimiento entrada: \(movimiento.id)")
                return .entrada(movimiento)
            }
            
        case .salida:
            if let movimiento = movimientosEgreso.first(where: { $0.id == movimientoDetalle.id }) {
                print("Encontrado movimiento salida: \(movimiento.id)")
                return .salida(movimiento)
            }
            
        case .transferencia:
            if let movimiento = movimientosEntreCarteras.first(where: { $0.id == movimientoDetalle.id }) {
                print("Encontrado movimiento transferencia: \(movimiento.id)")
                return .entreCarteras(movimiento)
            }
            
        case .swap:
            if let movimiento = movimientosSwap.first(where: { $0.id == movimientoDetalle.id }) {
                print("Encontrado movimiento swap: \(movimiento.id)")
                return .swap(movimiento)
            }
        }
        
        // Debug: Imprimir información para diagnóstico
        print("No se encontró el movimiento con ID: \(movimientoDetalle.id)")
        print("Tipo de movimiento: \(movimientoDetalle.tipo)")
        print("Cantidad de movimientos ingreso: \(movimientosIngreso.count)")
        print("Cantidad de movimientos egreso: \(movimientosEgreso.count)")
        print("Cantidad de movimientos transferencia: \(movimientosEntreCarteras.count)")
        print("Cantidad de movimientos swap: \(movimientosSwap.count)")
        
        return nil
    }
}


// MARK: - Tipo auxiliar para identificación
struct IdentifiableMovimientoDetalle: Identifiable {
    let id = UUID()
    let movimiento: MovimientoDetalle
}


// MARK: - Vista de Edición de Movimiento
struct EditMovimientoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var mode: EditMovementMode
    private var movimientoEntradaViewModel: MovimientoEntradaViewModel
 
        // Hacer el inicializador público
        init(mode: EditMovementMode, movimientoEntradaViewModel: MovimientoEntradaViewModel) {
            self.mode = mode
            self.movimientoEntradaViewModel = movimientoEntradaViewModel
        }
        
    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .entrada(let movimiento):
                    MovimientoEntradaFormView(
                        viewModel: self.movimientoEntradaViewModel
                    )
                case .salida(let movimiento):
                    MovimientoSalidaFormView(
                        viewModel: MovimientoSalidaViewModel(
                            modelContext: modelContext,
                            movimiento: movimiento
                        )
                    )
                case .entreCarteras(let movimiento):
                    MovimientoEntreCarterasFormView(
                        viewModel: MovimientoEntreCarterasViewModel(
                            modelContext: modelContext,
                            movimiento: movimiento
                        )
                    )
                case .swap(let movimiento):
                    MovimientoSwapFormView(
                        viewModel: MovimientoSwapViewModel(
                            modelContext: modelContext,
                            movimiento: movimiento
                        )
                    )
                }
            }
            .frame(minWidth: 500, minHeight: 700)
        }
    }
}

