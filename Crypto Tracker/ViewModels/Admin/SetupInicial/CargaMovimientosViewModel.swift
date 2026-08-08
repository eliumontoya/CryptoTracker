import SwiftUI
import SwiftData
import Combine

@MainActor
class CargaMovimientosViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var movimientosEntradaURL: URL?
    @Published var movimientosSalidaURL: URL?
    @Published var movimientosEntreCarterasURL: URL?
    @Published var movimientosSwapURL: URL?
    
    @Published var isLoading = false
    @Published var logs: [String] = []
    @Published var totalCargados: [String: Int] = [:]
    
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let holdingService: HoldingServiceProtocol
    private let readWorksheet: CargaMovimientosBatchService.WorksheetReader
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var hayArchivosSeleccionados: Bool {
        movimientosEntradaURL != nil ||
        movimientosSalidaURL != nil ||
        movimientosEntreCarterasURL != nil ||
        movimientosSwapURL != nil
    }

    // MARK: - Fetch Descriptors
    private var cryptosDescriptor: FetchDescriptor<Crypto> {
        FetchDescriptor<Crypto>(sortBy: [SortDescriptor(\.nombre)])
    }
    
    private var carterasDescriptor: FetchDescriptor<Cartera> {
        FetchDescriptor<Cartera>(sortBy: [SortDescriptor(\.nombre)])
    }
    
    private var fiatsDescriptor: FetchDescriptor<FIAT> {
        FetchDescriptor<FIAT>(sortBy: [SortDescriptor(\.nombre)])
    }

    // MARK: - Computed Catalogs
    var cryptos: [Crypto] {
        (try? modelContext.fetch(cryptosDescriptor)) ?? []
    }

    var carteras: [Cartera] {
        (try? modelContext.fetch(carterasDescriptor)) ?? []
    }

    var fiats: [FIAT] {
        (try? modelContext.fetch(fiatsDescriptor)) ?? []
    }

    var hayCatalogosNecesarios: Bool {
        !cryptos.isEmpty && !carteras.isEmpty && !fiats.isEmpty
    }

    // MARK: - Initializer
    init(
        modelContext: ModelContext,
        holdingService: HoldingServiceProtocol = HoldingService(),
        readWorksheet: @escaping CargaMovimientosBatchService.WorksheetReader = ExcelReader.read
    ) {
        self.modelContext = modelContext
        self.holdingService = holdingService
        self.readWorksheet = readWorksheet
    }
    
    // MARK: - Public Methods
    func cargarArchivos() {
        isLoading = true
        totalCargados.removeAll()
        logs.removeAll()

        Task {
            do {
                let service = CargaMovimientosBatchService(
                    modelContext: modelContext,
                    holdingService: holdingService,
                    readWorksheet: readWorksheet,
                    progress: didUpdateProgress
                )
                totalCargados = try await service.cargar(
                    archivos: CargaMovimientosFileSelection(
                        entrada: movimientosEntradaURL,
                        salida: movimientosSalidaURL,
                        entreCarteras: movimientosEntreCarterasURL,
                        swap: movimientosSwapURL
                    ),
                    cryptos: cryptos,
                    carteras: carteras,
                    fiats: fiats
                )
                didUpdateProgress("Carga completada correctamente")
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                logs.append("❌ ERROR: \(errorMessage). No se guardó ningún movimiento de esta carga.")
            }
            isLoading = false
        }
    }
}

// MARK: - CargaMovimientosDelegate Implementation
extension CargaMovimientosViewModel: CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String) {
        logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
    
    func didCompleteTask(_ type: String, total: Int) {
        totalCargados[type] = total
        isLoading = false
    }
    
    func didEncounterError(_ error: Error) {
        if let excelError = error as? ExcelWorksheetError {
            errorMessage = excelError.errorDescription ?? "Error desconocido"
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
        isLoading = false
        logs.append("❌ ERROR: \(errorMessage)")
    }
}
