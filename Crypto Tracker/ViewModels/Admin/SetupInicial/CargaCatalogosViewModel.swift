import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ViewModel
@MainActor
class CargaCatalogosViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var logs: [String] = []
    @Published var totalCargados: [String: Int] = [:]
    @Published var errorMessage: String = ""
    @Published var showError = false
    @Published private(set) var cargaCompletada = false
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Método público para cargar archivos
    func cargarArchivos(
        carterasURL: URL?,
        cryptosURL: URL?,
        fiatURL: URL?,
        syncURL: URL?
    ) async {
        isLoading = true
        cargaCompletada = false
        totalCargados.removeAll()
        
        do {
            // Cargar carteras si existe el archivo
            if let url = carterasURL {
                let total = try await cargarCarteras(desde: url)
                totalCargados["Carteras"] = total
            }
            
            // Cargar cryptos si existe el archivo
            if let url = cryptosURL {
                let total = try await cargarCryptos(desde: url)
                totalCargados["Cryptos"] = total
            }
            
            // Cargar FIAT si existe el archivo
            if let url = fiatURL {
                let total = try await cargarFIAT(desde: url)
                totalCargados["FIAT"] = total
            }
            
            // Cargar configuraciones de sync si existe el archivo
            if let url = syncURL {
                let total = try await cargarSyncConfig(desde: url)
                totalCargados["Sync"] = total
            }

            try modelContext.save()

            // Asegurar que todas las carteras (incluidas las recién cargadas)
            // estén vinculadas al portfolio activo.
            _ = PortfolioMigration.apply(in: modelContext)

            cargaCompletada = true
            agregarLog("✅ Proceso de carga completado exitosamente")
        } catch {
            modelContext.rollback()
            totalCargados.removeAll()
            mostrarError("Error durante la carga: \(error.localizedDescription)")
            agregarLog("❌ Error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // Métodos de carga con acceso interno para pruebas
    internal func cargarCarteras(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de Carteras...")

        // Asignar carteras al portfolio activo (o al primero disponible)
        let portfolio = PortfolioQueries.defaultPortfolio(in: modelContext)

        let contenido = try leerContenido(desde: url)
        var total = 0

        let lineas = contenido.components(separatedBy: .newlines)
        for linea in lineas where !linea.isEmpty {
            let campos = linea.components(separatedBy: ",")
            guard campos.count == 2 else {
                throw NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Formato inválido en línea: \(linea)"
                ])
            }

            let cartera = Cartera(
                nombre: campos[0].trimmingCharacters(in: .whitespaces),
                simbolo: campos[1].trimmingCharacters(in: .whitespaces),
                portfolio: portfolio
            )
            modelContext.insert(cartera)
            total += 1

            if total % 10 == 0 {
                agregarLog("Procesadas \(total) carteras...")
            }
        }

        agregarLog("Completada la carga de \(total) carteras")
        return total
    }
    
    internal func cargarCryptos(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de Cryptos...")
        
        let contenido = try leerContenido(desde: url)
        var total = 0
        
        let lineas = contenido.components(separatedBy: .newlines)
        for linea in lineas where !linea.isEmpty {
            let campos = linea.components(separatedBy: ",")
            guard campos.count == 2 else {
                throw NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Formato inválido en línea: \(linea)"
                ])
            }
            
            let crypto = Crypto(
                nombre: campos[0].trimmingCharacters(in: .whitespaces),
                simbolo: campos[1].trimmingCharacters(in: .whitespaces),
                precio: 0
            )
            modelContext.insert(crypto)
            total += 1
            
            if total % 10 == 0 {
                agregarLog("Procesadas \(total) cryptos...")
            }
        }
        
        agregarLog("Completada la carga de \(total) cryptos")
        return total
    }
    
    internal func cargarFIAT(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de FIAT...")
        
        let contenido = try leerContenido(desde: url)
        var total = 0
        
        let lineas = contenido.components(separatedBy: .newlines)
        for linea in lineas where !linea.isEmpty {
            let campos = linea.components(separatedBy: ",")
            guard campos.count == 3,
                  let precio = Decimal(string: campos[2].trimmingCharacters(in: .whitespaces)) else {
                throw NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Formato inválido en línea: \(linea)"
                ])
            }
            
            let fiat = FIAT(
                nombre: campos[0].trimmingCharacters(in: .whitespaces),
                simbolo: campos[1].trimmingCharacters(in: .whitespaces),
                precioUSD: precio
            )
            modelContext.insert(fiat)
            total += 1
            
            if total % 10 == 0 {
                agregarLog("Procesados \(total) FIAT...")
            }
        }
        
        agregarLog("Completada la carga de \(total) FIAT")
        return total
    }
    
    internal func cargarSyncConfig(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de configuraciones de Sync...")
        
        let contenido = try leerContenido(desde: url)
        var total = 0
        
        // Obtener todas las cryptos para buscar coincidencias
        let descriptor = FetchDescriptor<Crypto>(sortBy: [SortDescriptor(\.simbolo)])
        let cryptos = try modelContext.fetch(descriptor)
        
        let lineas = contenido.components(separatedBy: .newlines)
        for linea in lineas where !linea.isEmpty {
            let campos = linea.components(separatedBy: ",")
            guard campos.count == 3,
                  let precioDefault = Decimal(string: campos[2].trimmingCharacters(in: .whitespaces)) else {
                throw NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Formato inválido en línea: \(linea)"
                ])
            }
            
            let simboloCrypto = campos[0].trimmingCharacters(in: .whitespaces)
            guard let crypto = cryptos.first(where: { $0.simbolo == simboloCrypto }) else {
                agregarLog("⚠️ Crypto no encontrada para símbolo: \(simboloCrypto)")
                continue
            }
            
            let config = CryptoSyncConfig(
                crypto: crypto,
                syncUrl: campos[1].trimmingCharacters(in: .whitespaces),
                defaultPrice: precioDefault
            )
            modelContext.insert(config)
            total += 1
            
            if total % 10 == 0 {
                agregarLog("Procesadas \(total) configuraciones...")
            }
        }
        
        agregarLog("Completada la carga de \(total) configuraciones de sync")
        return total
    }
    
    // Métodos auxiliares
    private func leerContenido(desde url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No se pudo acceder al archivo \"\(url.lastPathComponent)\". Seleccione el archivo nuevamente."
            ])
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    private func agregarLog(_ mensaje: String) {
        logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(mensaje)")
    }

    private func mostrarError(_ error: String) {
        errorMessage = error
        showError = true
    }
}
