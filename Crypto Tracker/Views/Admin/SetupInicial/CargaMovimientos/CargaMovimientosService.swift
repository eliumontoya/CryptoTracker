import Foundation
import SwiftData

// MARK: - CargaMovimientosDelegate
protocol CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String)
    func didCompleteTask(_ type: String, total: Int)
    func didEncounterError(_ error: Error)
}

// MARK: - CargaMovimientosService
class CargaMovimientosService {
    private let modelContext: ModelContext
    private var delegate: CargaMovimientosDelegate?
    
    
    init(modelContext: ModelContext, delegate: CargaMovimientosDelegate) {
        self.modelContext = modelContext
        self.delegate = delegate
    }
    
    // MARK: - Carga de Movimientos de Entrada
    func cargarMovimientosEntrada(desde url: URL) async throws -> Int {
        delegate?.didUpdateProgress("Iniciando carga de Movimientos de Entrada...")
        
        // Leer archivo Excel
        let worksheet = try await ExcelReader.read(from: url)
        
        // Obtener catálogos necesarios
        let cryptos = try modelContext.fetch(FetchDescriptor<Crypto>())
        let carteras = try modelContext.fetch(FetchDescriptor<Cartera>())
        let fiats = try modelContext.fetch(FetchDescriptor<FIAT>())
        
        // Procesar movimientos
        let movimientos = try MovimientosParser.parseMovimientoEntrada(
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
