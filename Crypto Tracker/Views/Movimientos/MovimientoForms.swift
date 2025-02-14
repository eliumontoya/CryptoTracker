// MovimientoForms.swift
import SwiftUI
import SwiftData

// MARK: - Vista de Edición General
struct EditMovimientoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let movimientoDetalle: MovimientoDetalle
    
    var body: some View {
        NavigationStack {
            Group {
                switch movimientoDetalle.tipo {
                case .entrada:
                    if let movimiento = findMovimientoIngreso() {
                        MovimientoEntradaFormView(
                            viewModel: MovimientoEntradaViewModel(
                                modelContext: modelContext,
                                movimiento: movimiento
                            )
                        )
                    }
                case .salida:
                    // TODO: Actualizar cuando se implemente el ViewModel de Salida
                    EmptyView()
                case .transferencia:
                    // TODO: Actualizar cuando se implemente el ViewModel de EntreCarteras
                    EmptyView()
                case .swap:
                    // TODO: Actualizar cuando se implemente el ViewModel de Swap
                    EmptyView()
                }
            }
            .frame(minWidth: 500, minHeight: 700)
        }
    }
    
    private func findMovimientoIngreso() -> MovimientoIngreso? {
        let searchId = movimientoDetalle.id
        let descriptor = FetchDescriptor<MovimientoIngreso>(
            predicate: #Predicate<MovimientoIngreso> {
                $0.id == searchId
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Vista para buscar el movimiento correcto
struct MovimientoSearchView: View {
    @Environment(\.modelContext) private var modelContext
    let movimientoDetalle: MovimientoDetalle
    
    var body: some View {
        EditMovimientoView(movimientoDetalle: movimientoDetalle)
    }
}

// MARK: - Tipo auxiliar para identificación
struct IdentifiableMovimientoDetalle: Identifiable {
    let id = UUID()
    let movimientoDetalle: MovimientoDetalle
}
