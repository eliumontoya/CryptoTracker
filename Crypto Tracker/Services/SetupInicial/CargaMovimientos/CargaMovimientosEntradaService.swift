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
            await MainActor.run { delegate?.didUpdateProgress("Iniciando carga de Movimientos de Entrada...") }
            
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
            for (index, movimiento) in movimientos.enumerated() {
                modelContext.insert(movimiento)
                
                if (index + 1) % 10 == 0 {
                    await MainActor.run { delegate?.didUpdateProgress("Procesados \(index + 1) movimientos...") }
                }
            }
            
            try modelContext.save()
            
            await MainActor.run {
                delegate?.didUpdateProgress("Completada la carga de \(movimientos.count) movimientos de entrada")
                delegate?.didCompleteTask("Movimientos de Entrada", total: movimientos.count)
            }
            
            return movimientos.count
        }
}
