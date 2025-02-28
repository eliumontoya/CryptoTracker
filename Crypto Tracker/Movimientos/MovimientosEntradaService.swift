//
//  MovimientosService.swift
//  Crypto Tracker
//
//  Created by Eliu Montoya on 21/02/25.
//

import Foundation
import SwiftData

struct ValidacionError: Error {
    let errores: [ErrorInformacionFaltante]
}


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
    
    
    
    private func validateMovimiento (movimiento: MovimientoIngreso)   throws {
        var errores: [ErrorInformacionFaltante] = []
        
        //obligatorio:
        if movimiento.crypto == nil {
            errores.append(ErrorInformacionFaltante.cryptoNoVacia)
            
        }
        if movimiento.cartera == nil {
            errores.append(ErrorInformacionFaltante.carteraNoVacia)
            
        }
        if movimiento.precioUSD <= 0 || movimiento.valorTotalUSD <= 0  || movimiento.cantidadCrypto <= 0  {
            errores.append(ErrorInformacionFaltante.infoFaltante)
            
        }
        
        
        // Si se usa fiat, verificar obligatorios
        if movimiento.usaFiatAlterno {
            if let precio = movimiento.precioFiatAlterno, let valorTotal = movimiento.valorTotalFiatAlterno {
                if precio <= 0 || valorTotal <= 0 {
                    errores.append(ErrorInformacionFaltante.fiatNoValido)
                    
                } }
            
            
        }
        
        
        if !errores.isEmpty {
            throw ValidacionError(errores: errores)
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

