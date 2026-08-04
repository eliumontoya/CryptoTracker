import Foundation
import SwiftData

class CargaMovimientosEntreCarterasService {
    private let modelContext: ModelContext
    private var delegate: CargaMovimientosDelegate?
    
    init(modelContext: ModelContext, delegate: CargaMovimientosDelegate? = nil) {
        self.modelContext = modelContext
        self.delegate = delegate
    }
    
    func cargarMovimientos( desde url: URL,
                            cryptos: [Crypto],
                            carteras: [Cartera]
    ) async throws -> Int {
        await MainActor.run { delegate?.didUpdateProgress("Iniciando carga de Movimientos Entre Carteras...") }
        
        // Leer archivo Excel
        let worksheet = try await ExcelReader.read(from: url)
        
        // Procesar movimientos (skipFundCheck: true porque es carga inicial sin movimientos previos)
        let movimientos = try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: carteras,
            cryptos: cryptos,
            skipFundCheck: true
        )
        
        // Insertar movimientos en la base de datos
        for (index, movimiento) in movimientos.enumerated() {
            modelContext.insert(movimiento)
            
            if (index + 1) % 10 == 0 {
                await MainActor.run { delegate?.didUpdateProgress("Procesados \(index + 1) movimientos...") }
            }
        }
        
        try modelContext.save()
        
        await MainActor.run {
            delegate?.didUpdateProgress("Completada la carga de \(movimientos.count) movimientos entre carteras")
            delegate?.didCompleteTask("Movimientos Entre Carteras", total: movimientos.count)
        }
        
        return movimientos.count
    }
}
