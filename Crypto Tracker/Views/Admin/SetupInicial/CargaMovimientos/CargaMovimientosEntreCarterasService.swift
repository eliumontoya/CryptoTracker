import Foundation
import SwiftData

class CargaMovimientosEntreCarterasService {
    private let modelContext: ModelContext
    private var delegate: CargaMovimientosDelegate?
    
    init(modelContext: ModelContext, delegate: CargaMovimientosDelegate? = nil) {
        self.modelContext = modelContext
        self.delegate = delegate
    }
    
    func cargarMovimientos(desde url: URL) async throws -> Int {
        delegate?.didUpdateProgress("Iniciando carga de Movimientos Entre Carteras...")
        
        // Leer archivo Excel
        let worksheet = try await ExcelReader.read(from: url)
        
        // Obtener catálogos necesarios
        let cryptos = try modelContext.fetch(FetchDescriptor<Crypto>())
        let carteras = try modelContext.fetch(FetchDescriptor<Cartera>())
        
        // Procesar movimientos
        let movimientos = try MovimientoEntreCarterasParser.parse(
            worksheet: worksheet,
            carteras: carteras,
            cryptos: cryptos
        )
        
        // Insertar movimientos en la base de datos
        for movimiento in movimientos {
            modelContext.insert(movimiento)
            
            if movimientos.count % 10 == 0 {
                delegate?.didUpdateProgress("Procesados \(movimientos.count) movimientos...")
            }
        }
        
        try modelContext.save()
        
        delegate?.didUpdateProgress("Completada la carga de \(movimientos.count) movimientos entre carteras")
        delegate?.didCompleteTask("Movimientos Entre Carteras", total: movimientos.count)
        
        return movimientos.count
    }
}
