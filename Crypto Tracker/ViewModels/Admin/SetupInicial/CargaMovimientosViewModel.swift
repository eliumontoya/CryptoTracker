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
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var hayArchivosSeleccionados: Bool {
        movimientosEntradaURL != nil ||
        movimientosSalidaURL != nil ||
        movimientosEntreCarterasURL != nil ||
        movimientosSwapURL != nil
    }
    
    // MARK: - Fetch Descriptors
    private lazy var cryptosDescriptor = FetchDescriptor<Crypto>(sortBy: [SortDescriptor(\.nombre)])
    private lazy var carterasDescriptor = FetchDescriptor<Cartera>(sortBy: [SortDescriptor(\.nombre)])
    private lazy var fiatsDescriptor = FetchDescriptor<FIAT>(sortBy: [SortDescriptor(\.nombre)])
    
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
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    func cargarArchivos() {
        isLoading = true
        totalCargados.removeAll()
        logs.removeAll()
        
        // Obtener los catálogos una sola vez
        let cryptosActuales = cryptos
        let carterasActuales = carteras
        let fiatsActuales = fiats
        
        Task {
            do {
                // Cargar movimientos de entrada si existe el archivo
                if let url = movimientosEntradaURL {
                    let total = try await cargarMovimientosEntrada(
                        desde: url,
                        cryptos: cryptosActuales,
                        carteras: carterasActuales,
                        fiats: fiatsActuales
                    )
                    
                    DispatchQueue.main.async {
                        self.totalCargados["Movimientos de Entrada"] = total
                    }
                }
                
                // Cargar movimientos de salida si existe el archivo
                if let url = movimientosSalidaURL {
                    let total = try await cargarMovimientosSalida(
                        desde: url,
                        cryptos: cryptosActuales,
                        carteras: carterasActuales,
                        fiats: fiatsActuales
                    )
                    
                    DispatchQueue.main.async {
                        self.totalCargados["Movimientos de Salida"] = total
                    }
                }
                
                // Cargar movimientos entre carteras si existe el archivo
                if let url = movimientosEntreCarterasURL {
                    let total = try await cargarMovimientosEntreCarteras(
                        desde: url,
                        cryptos: cryptosActuales,
                        carteras: carterasActuales
                    )
                    
                    DispatchQueue.main.async {
                        self.totalCargados["Movimientos Entre Carteras"] = total
                    }
                }
                
                // Cargar movimientos swap si existe el archivo
                if let url = movimientosSwapURL {
                    let total = try await cargarMovimientosSwap(
                        desde: url,
                        cryptos: cryptosActuales,
                        carteras: carterasActuales
                    )
                    
                    DispatchQueue.main.async {
                        self.totalCargados["Movimientos Swap"] = total
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Private Loading Methods
    private func cargarMovimientosEntrada(
        desde url: URL,
        cryptos: [Crypto],
        carteras: [Cartera],
        fiats: [FIAT]
    ) async throws -> Int {
        let service = CargaMovimientosEntradaService(
            modelContext: modelContext,
            delegate: self
        )
        
        return try await service.cargarMovimientos(
            desde: url,
            cryptos: cryptos,
            carteras: carteras,
            fiats: fiats
        )
    }
    
    private func cargarMovimientosSalida(
        desde url: URL,
        cryptos: [Crypto],
        carteras: [Cartera],
        fiats: [FIAT]
    ) async throws -> Int {
        let service = CargaMovimientosSalidaService(
            modelContext: modelContext,
            delegate: self
        )
        
        return try await service.cargarMovimientos(
            desde: url,
            cryptos: cryptos,
            carteras: carteras,
            fiats: fiats
        )
    }
    
    private func cargarMovimientosEntreCarteras(
        desde url: URL,
        cryptos: [Crypto],
        carteras: [Cartera]
    ) async throws -> Int {
        let service = CargaMovimientosEntreCarterasService(
            modelContext: modelContext,
            delegate: self
        )
        
        return try await service.cargarMovimientos(
            desde: url,
            cryptos: cryptos,
            carteras: carteras
        )
    }
    
    private func cargarMovimientosSwap(
        desde url: URL,
        cryptos: [Crypto],
        carteras: [Cartera]
    ) async throws -> Int {
        let service = CargaMovimientosSwapService(
            modelContext: modelContext,
            delegate: self
        )
        
        return try await service.cargarMovimientos(
            desde: url,
            cryptos: cryptos,
            carteras: carteras
        )
    }
}

// MARK: - CargaMovimientosDelegate Implementation
extension CargaMovimientosViewModel: CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String) {
        DispatchQueue.main.async {
            self.logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
        }
    }
    
    func didCompleteTask(_ type: String, total: Int) {
        DispatchQueue.main.async {
            self.totalCargados[type] = total
            self.isLoading = false
        }
    }
    
    func didEncounterError(_ error: Error) {
        DispatchQueue.main.async {
            if let excelError = error as? ExcelWorksheetError {
                self.errorMessage = excelError.errorDescription ?? "Error desconocido"
            } else {
                self.errorMessage = error.localizedDescription
            }
            self.showError = true
            self.isLoading = false
            self.logs.append("❌ ERROR: \(self.errorMessage)")
        }
    }
}
