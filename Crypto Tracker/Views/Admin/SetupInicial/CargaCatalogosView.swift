import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CargaCatalogosView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Estados para los archivos seleccionados
    @State private var carterasURL: URL?
    @State private var cryptosURL: URL?
    @State private var fiatURL: URL?
    @State private var syncURL: URL?
    
    // Estado para mostrar progreso de carga
    @State private var isLoading = false
    @State private var logs: [String] = []
    @State private var totalCargados = [String: Int]()
    
    // Estados para manejo de errores
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Tipos de archivo permitidos
    let csvType = UTType(filenameExtension: "csv")!
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icono y título
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Carga de Catálogos Iniciales")
                    .font(.title)
                    .bold()
                
                Text("Seleccione los archivos CSV para cada catálogo. Los archivos deben tener el formato específico indicado.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Sección de selección de archivos
                VStack(spacing: 16) {
                    FileSelectionRow(
                        title: "Carteras",
                        subtitle: "Formato: Nombre,Simbolo",
                        url: $carterasURL,
                        type: csvType
                    )
                    
                    FileSelectionRow(
                        title: "Cryptos",
                        subtitle: "Formato: Nombre,Simbolo",
                        url: $cryptosURL,
                        type: csvType
                    )
                    
                    FileSelectionRow(
                        title: "FIAT",
                        subtitle: "Formato: Nombre,Simbolo,Precio",
                        url: $fiatURL,
                        type: csvType
                    )
                    
                    FileSelectionRow(
                        title: "Sync Manual",
                        subtitle: "Formato: Simbolo de Crypto,URL,Precio Default",
                        url: $syncURL,
                        type: csvType
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Botón de carga
                Button(action: cargarArchivos) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Iniciar Carga")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || !hayArchivosSeleccionados)
                .padding(.horizontal)
                
                // Área de logs
                if !logs.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Log de operaciones:")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .padding()
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Resumen de carga
                if !totalCargados.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumen de carga:")
                            .font(.headline)
                        
                        ForEach(Array(totalCargados.keys.sorted()), id: \.self) { key in
                            if let total = totalCargados[key] {
                                Text("\(key): \(total) registros cargados")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") {
                    dismiss()
                }
                .disabled(isLoading)
            }
        }
    }
    
    private var hayArchivosSeleccionados: Bool {
        carterasURL != nil || cryptosURL != nil || fiatURL != nil || syncURL != nil
    }
    
    private func agregarLog(_ mensaje: String) {
        DispatchQueue.main.async {
            logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(mensaje)")
        }
    }
    
    private func mostrarError(_ error: String) {
        DispatchQueue.main.async {
            errorMessage = error
            showError = true
        }
    }
    
    private func cargarArchivos() {
        isLoading = true
        totalCargados.removeAll()
        
        Task {
            do {
                // Cargar carteras si existe el archivo
                if let url = carterasURL {
                    let total = try await cargarCarteras(desde: url)
                    DispatchQueue.main.async {
                        totalCargados["Carteras"] = total
                    }
                }
                
                // Cargar cryptos si existe el archivo
                if let url = cryptosURL {
                    let total = try await cargarCryptos(desde: url)
                    DispatchQueue.main.async {
                        totalCargados["Cryptos"] = total
                    }
                }
                
                // Cargar FIAT si existe el archivo
                if let url = fiatURL {
                    let total = try await cargarFIAT(desde: url)
                    DispatchQueue.main.async {
                        totalCargados["FIAT"] = total
                    }
                }
                
                // Cargar configuraciones de sync si existe el archivo
                if let url = syncURL {
                    let total = try await cargarSyncConfig(desde: url)
                    DispatchQueue.main.async {
                        totalCargados["Sync"] = total
                    }
                }
                
                agregarLog("✅ Proceso de carga completado exitosamente")
            } catch {
                mostrarError("Error durante la carga: \(error.localizedDescription)")
                agregarLog("❌ Error: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
    
    private func cargarCarteras(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de Carteras...")
        
        let contenido = try String(contentsOf: url, encoding: .utf8)
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
                simbolo: campos[1].trimmingCharacters(in: .whitespaces)
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
    
    private func cargarCryptos(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de Cryptos...")
        
        let contenido = try String(contentsOf: url, encoding: .utf8)
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
    
    private func cargarFIAT(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de FIAT...")
        
        let contenido = try String(contentsOf: url, encoding: .utf8)
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
    
    private func cargarSyncConfig(desde url: URL) async throws -> Int {
        agregarLog("Iniciando carga de configuraciones de Sync...")
        
        let contenido = try String(contentsOf: url, encoding: .utf8)
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
}


#Preview {
    CargaCatalogosView()
        .frame(width: 800, height: 600)
        .withPreviewContainer()
}
