import Foundation
import SwiftData

@MainActor
class CargaMovimientosSwapService {
    typealias WorksheetReader = (URL) async throws -> ExcelWorksheet

    private let modelContext: ModelContext
    private var delegate: CargaMovimientosDelegate?
    private let readWorksheet: WorksheetReader
    
    init(
        modelContext: ModelContext,
        delegate: CargaMovimientosDelegate? = nil,
        readWorksheet: @escaping WorksheetReader = ExcelReader.read
    ) {
        self.modelContext = modelContext
        self.delegate = delegate
        self.readWorksheet = readWorksheet
    }
    
    func cargarMovimientos(
        desde url: URL,
        cryptos: [Crypto],
        carteras: [Cartera]
    ) async throws -> Int {
        await MainActor.run { delegate?.didUpdateProgress("Iniciando carga de Movimientos Swap...") }
        
        // Leer archivo Excel
        let worksheet = try await readWorksheet(url)
        
        // Procesar movimientos (skipFundCheck: true porque es carga inicial sin movimientos previos)
        let movimientos = try MovimientoSwapParser.parse(
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
            delegate?.didUpdateProgress("Completada la carga de \(movimientos.count) movimientos swap")
            delegate?.didCompleteTask("Movimientos Swap", total: movimientos.count)
        }
        
        return movimientos.count
    }
}
