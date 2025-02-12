import Foundation
import SwiftData

class CargaMovimientosEntradaService {
    private let modelContext: ModelContext
    private var delegate: CargaMovimientosDelegate?
    
    init(modelContext: ModelContext, delegate: CargaMovimientosDelegate? = nil) {
        self.modelContext = modelContext
        self.delegate = delegate
    }
    
    func cargarMovimientos(
            desde url: URL,
            cryptos: [Crypto],
            carteras: [Cartera],
            fiats: [FIAT]
        ) async throws -> Int {
            delegate?.didUpdateProgress("Iniciando carga de Movimientos de Entrada...")
            
            // Leer archivo Excel
            let worksheet = try await ExcelReader.read(from: url)
            
            // Procesar movimientos
            let movimientos = try MovimientoEntradaParser.parse(
                worksheet: worksheet,
                carteras: carteras,
                cryptos: cryptos,
                fiats: fiats
            )
            
            // Insertar movimientos en la base de datos
            for movimiento in movimientos {
                modelContext.insert(movimiento)
                
                if movimientos.count % 10 == 0 {
                    delegate?.didUpdateProgress("Procesados \(movimientos.count) movimientos...")
                }
            }
            
            try modelContext.save()
            
            delegate?.didUpdateProgress("Completada la carga de \(movimientos.count) movimientos de entrada")
            delegate?.didCompleteTask("Movimientos de Entrada", total: movimientos.count)
            
            return movimientos.count
        }
}
