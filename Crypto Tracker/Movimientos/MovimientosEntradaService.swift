//
//  MovimientosService.swift
//  Crypto Tracker
//
//  Created by Eliu Montoya on 21/02/25.
//

import Foundation
import SwiftData

// Errores específicos del servicio
enum MovimientoServiceError: Error, LocalizedError {
    case fetchFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case invalidMovimiento
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Error al obtener movimientos: \(message)"
        case .saveFailed(let message):
            return "Error al guardar movimiento: \(message)"
        case .deleteFailed(let message):
            return "Error al eliminar movimiento: \(message)"
        case .invalidMovimiento:
            return "El movimiento no es válido o falta información requerida"
        }
    }
}


protocol MovimientosEntradaServiceProtocol {
    func save(movimiento: MovimientoIngreso) throws
    func insert(movimiento: MovimientoIngreso) throws
    func delete(movimiento: MovimientoIngreso) throws
    
    func fetch() throws -> [MovimientoIngreso]
    func fetchSorted() throws -> [MovimientoIngreso]
    
    func checkCryptoDisponible(crypto: Crypto, cartera: Cartera) -> Decimal
    
}

class MovimientosEntradaService : ObservableObject,MovimientosEntradaServiceProtocol{
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
    }
    
    func fetch() throws -> [MovimientoIngreso] {
        do {
            let descriptor = FetchDescriptor<MovimientoIngreso>()
            return try modelContext.fetch(descriptor)
        } catch {
            throw MovimientoServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    func fetchSorted() throws -> [MovimientoIngreso] {
        do {
            let descriptor = FetchDescriptor<MovimientoIngreso>(
                sortBy: [SortDescriptor(\.fecha, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            throw MovimientoServiceError.fetchFailed(error.localizedDescription)
        }
    }
    
    
    
    private func validateMovimiento(movimiento: MovimientoIngreso) throws {
        if movimiento.crypto == nil {
            throw MovimientoFormCommonError.missingCrypto
        }
        if movimiento.cartera == nil {
            throw MovimientoFormCommonError.missingCartera
        }
        if movimiento.precioUSD <= 0 || movimiento.valorTotalUSD <= 0 || movimiento.cantidadCrypto <= 0 {
            throw MovimientoFormCommonError.invalidAmount
        }

        if movimiento.usaFiatAlterno {
            if let precio = movimiento.precioFiatAlterno, let valorTotal = movimiento.valorTotalFiatAlterno {
                if precio <= 0 || valorTotal <= 0 {
                    throw MovimientoFormCommonError.invalidFiat
                }
            } else {
                throw MovimientoFormCommonError.invalidFiat
            }
        }
    }
    
    func save(movimiento: MovimientoIngreso) throws{
        try validateMovimiento(movimiento: movimiento)
        
        do {
            try modelContext.save()
        } catch {
            throw MovimientoServiceError.saveFailed(error.localizedDescription)
        }
    }
    
    
    func insert(movimiento: MovimientoIngreso) throws{
        try validateMovimiento(movimiento: movimiento)
        do {
            modelContext.insert(movimiento)
            try modelContext.save()
        } catch {
            throw MovimientoServiceError.saveFailed(error.localizedDescription)
        }    }
    
    func delete(movimiento: MovimientoIngreso) throws {
        do {
            modelContext.delete(movimiento)
            try modelContext.save()
        } catch {
            throw MovimientoServiceError.deleteFailed(error.localizedDescription)
        }
    }
    
    // Esta función es útil para validaciones al crear/editar movimientos
        func checkCryptoDisponible(crypto: Crypto, cartera: Cartera) -> Decimal {
            return cartera.getCryptoDisponible(crypto: crypto)
        }
    
}

