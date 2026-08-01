// MovimientoSharedTypes.swift
import Foundation

 

// MARK: - Shared View Models & Protocols
@MainActor
protocol MovimientoViewModel: ObservableObject {
    var fecha: Date { get set }
    var isLoading: Bool { get set }
    var hasError: Bool { get set }
    var errorMessage: String { get set }
    var formIsValid: Bool { get }
    var uiState: MovimientoUIState { get }

    func save() async throws
    func delete() async throws
}
 

// MARK: - Form Validation Errors
enum MovimientoFormCommonError: Error, LocalizedError {
    case missingCrypto
    case missingCartera
    case invalidAmount
    case insufficientFunds
    case invalidPrice
    case sameCartera
    case invalidFiat
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCrypto:
            return "Debe seleccionar una criptomoneda"
        case .missingCartera:
            return "Debe seleccionar una cartera"
        case .invalidAmount:
            return "La cantidad debe ser mayor que cero"
        case .insufficientFunds:
            return "No hay suficientes fondos en la cartera"
        case .invalidPrice:
            return "El precio debe ser mayor que cero"
        case .sameCartera:
            return "La cartera origen y destino no pueden ser la misma"
        case .invalidFiat:
            return "La moneda FIAT alterna no es válida"
        case .saveFailed(let message):
            return "Error al guardar: \(message)"
        }
    }
}

  

// Estados de UI comunes para los ViewModels de movimientos
enum MovimientoUIState: Equatable {
    case idle
    case loading
    case success
    case error(String)
    
    static func == (lhs: MovimientoUIState, rhs: MovimientoUIState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.success, .success):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - Extensions
extension TipoMovimientoDetalle {
    var icon: String {
        switch self {
        case .entrada: return "arrow.down.circle.fill"
        case .salida: return "arrow.up.circle.fill"
        case .transferencia: return "arrow.left.arrow.right.circle.fill"
        case .swap: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .entrada: return "green"
        case .salida: return "red"
        case .transferencia: return "blue"
        case .swap: return "orange"
        }
    }
    
    var title: String {
        switch self {
        case .entrada: return "Entrada"
        case .salida: return "Salida"
        case .transferencia: return "Transferencia"
        case .swap: return "Swap"
        }
    }
}
