import Foundation
import SwiftData

class CargaMovimientosSalidaService {
    private let modelContext: ModelContext
    private var delegate: CargaMovimientosDelegate?
    
    init(modelContext: ModelContext, delegate: CargaMovimientosDelegate? = nil) {
        self.modelContext = modelContext
        self.delegate = delegate
    }
    
    func cargarMovimientos( desde url: URL,
                            cryptos: [Crypto],
                            carteras: [Cartera],
                            fiats: [FIAT]
    ) async throws -> Int {
        await MainActor.run { delegate?.didUpdateProgress("Iniciando carga de Movimientos de Salida...") }
        
        // Leer archivo Excel
        let worksheet = try await ExcelReader.read(from: url)
        
        // Obtener catálogos necesarios
        let cryptos = try modelContext.fetch(FetchDescriptor<Crypto>())
        let carteras = try modelContext.fetch(FetchDescriptor<Cartera>())
        let fiats = try modelContext.fetch(FetchDescriptor<FIAT>())
        
        // Procesar movimientos
        let movimientos = try MovimientoSalidaParser.parse(
            worksheet: worksheet,
            carteras: carteras,
            cryptos: cryptos,
            fiats: fiats
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
            delegate?.didUpdateProgress("Completada la carga de \(movimientos.count) movimientos de salida")
            delegate?.didCompleteTask("Movimientos de Salida", total: movimientos.count)
        }
        
        return movimientos.count
    }
}
