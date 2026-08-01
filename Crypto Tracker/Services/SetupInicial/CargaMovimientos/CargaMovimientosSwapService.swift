import Foundation
import SwiftData

class CargaMovimientosSwapService {
    private let modelContext: ModelContext
    private var delegate: CargaMovimientosDelegate?
    
    init(modelContext: ModelContext, delegate: CargaMovimientosDelegate? = nil) {
        self.modelContext = modelContext
        self.delegate = delegate
    }
    
    func cargarMovimientos(
        desde url: URL,
        cryptos: [Crypto],
        carteras: [Cartera]
    ) async throws -> Int {
        await MainActor.run { delegate?.didUpdateProgress("Iniciando carga de Movimientos Swap...") }
        
        // Leer archivo Excel
        let worksheet = try await ExcelReader.read(from: url)
        
        // Procesar movimientos
        let movimientos = try MovimientoSwapParser.parse(
            worksheet: worksheet,
            carteras: carteras,
            cryptos: cryptos
        )
        
        // Insertar movimientos en la base de datos
        for movimiento in movimientos {
            modelContext.insert(movimiento)
            
            if movimientos.count % 10 == 0 {
                await MainActor.run { delegate?.didUpdateProgress("Procesados \(movimientos.count) movimientos...") }
            }
        }
        
        try modelContext.save()
        
        await MainActor.run {
            delegate?.didUpdateProgress("Completada la carga de \(movimientos.count) movimientos swap")
            delegate?.didCompleteTask("Movimientos Swap", total: movimientos.count)
        }
        
        return movimientos.count
    }
}
