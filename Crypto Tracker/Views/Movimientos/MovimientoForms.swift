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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let movimientoDetalle: MovimientoDetalle
    
    @Query private var movimientosIngreso: [MovimientoIngreso]
    @Query private var movimientosEgreso: [MovimientoEgreso]
    @Query private var movimientosEntreCarteras: [MovimientoEntreCarteras]
    @Query private var movimientosSwap: [MovimientoSwap]
    
    var body: some View {
        NavigationStack {
            if let mode = findEditMode() {
                EditMovimientoView(mode: mode)
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
    let mode: EditMovementMode
    
    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .entrada(let movimiento):
                    MovimientoEntradaFormView(
                        viewModel: MovimientoEntradaViewModel(
                            modelContext: ModelContext(try! ModelContainer(for: MovimientoIngreso.self)),
                            movimiento: movimiento
                        )
                    )
                case .salida(let movimiento):
                    MovimientoSalidaFormView(
                        viewModel: MovimientoSalidaViewModel(
                            modelContext: ModelContext(try! ModelContainer(for: MovimientoEgreso.self)),
                            movimiento: movimiento
                        )
                    )
                case .entreCarteras(let movimiento):
                    MovimientoEntreCarterasFormView(
                        viewModel: MovimientoEntreCarterasViewModel(
                            modelContext: ModelContext(try! ModelContainer(for: MovimientoEntreCarteras.self)),
                            movimiento: movimiento
                        )
                    )
                case .swap(let movimiento):
                    MovimientoSwapFormView(
                        viewModel: MovimientoSwapViewModel(
                            modelContext: ModelContext(try! ModelContainer(for: MovimientoSwap.self)),
                            movimiento: movimiento
                        )
                    )
                }
            }
            .frame(minWidth: 500, minHeight: 700)
        }
    }
}
