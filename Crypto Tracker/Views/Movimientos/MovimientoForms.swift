// MovimientoForms.swift
import SwiftUI
import SwiftData

// MARK: - Vista para buscar el movimiento correcto
enum EditMovementMode: Equatable {
    case movimiento(Movimiento)
}

// MARK: - Vista para buscar el movimiento correcto
struct MovimientoSearchView: View {
    @StateObject private var movimientoEntradaViewModel: MovimientoEntradaViewModel
    let movimientoDetalle: MovimientoDetalle
    private let dependencies: AppDependencyContainer

    init(movimientoDetalle: MovimientoDetalle, dependencies: AppDependencyContainer) {
        self.movimientoDetalle = movimientoDetalle
        self.dependencies = dependencies
        _movimientoEntradaViewModel = StateObject(wrappedValue:
            dependencies.makeMovimientoEntradaViewModel())
    }

    @Query private var movimientos: [Movimiento]

    var body: some View {
        NavigationStack {
            if let mode = findEditMode() {
                EditMovimientoView(
                    mode: mode,
                    movimientoEntradaViewModel: self.movimientoEntradaViewModel,
                    dependencies: dependencies
                )
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
        if let movimiento = movimientos.first(where: { $0.id == movimientoDetalle.id }) {
            print("Encontrado movimiento: \(movimiento.id)")
            return .movimiento(movimiento)
        }

        // Debug: Imprimir información para diagnóstico
        print("No se encontró el movimiento con ID: \(movimientoDetalle.id)")
        print("Tipo de movimiento: \(movimientoDetalle.tipo)")
        print("Cantidad de movimientos: \(movimientos.count)")

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
    var mode: EditMovementMode
    private var movimientoEntradaViewModel: MovimientoEntradaViewModel
    private let dependencies: AppDependencyContainer

        // Hacer el inicializador público
        init(mode: EditMovementMode, movimientoEntradaViewModel: MovimientoEntradaViewModel, dependencies: AppDependencyContainer) {
            self.mode = mode
            self.movimientoEntradaViewModel = movimientoEntradaViewModel
            self.dependencies = dependencies
        }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .movimiento(let movimiento):
                    switch movimiento.tipo {
                    case .entrada:
                        EntradaEditView(
                            movimiento: movimiento,
                            viewModel: movimientoEntradaViewModel
                        )
                    case .salida:
                        dependencies.makeMovimientoSalidaFormView(movimiento: movimiento)
                    case .transferenciaSalida, .transferenciaEntrada:
                        dependencies.makeMovimientoEntreCarterasFormView(movimiento: movimiento)
                    case .swapSalida, .swapEntrada:
                        dependencies.makeMovimientoSwapFormView(movimiento: movimiento)
                    case .ajuste, .comision:
                        ContentUnavailableView(
                            "Movimiento no editable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Este tipo de movimiento no se puede editar desde aquí.")
                        )
                    }
                }
            }
            .adaptiveSheetFrame()
        }
    }
}

// MARK: - Edición de entrada
/// Recarga el ViewModel compartido de entrada con el movimiento a editar y
/// presenta el formulario.
struct EntradaEditView: View {
    let movimiento: Movimiento
    let viewModel: MovimientoEntradaViewModel

    init(movimiento: Movimiento, viewModel: MovimientoEntradaViewModel) {
        self.movimiento = movimiento
        self.viewModel = viewModel
        viewModel.loadMovimiento(movimiento)
    }

    var body: some View {
        MovimientoEntradaFormView(viewModel: viewModel)
    }
}
