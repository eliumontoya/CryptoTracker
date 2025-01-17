// MARK: - CryptoSyncConfig Model
import SwiftData
import SwiftUI
 

// MARK: - Log Entry Model
struct SyncLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cryptoSymbol: String
    let message: String
    let isError: Bool
}

// MARK: - Price Response Model
struct PriceResponse: Codable {
    let price: Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Buscar cualquier clave en el primer nivel
        guard let firstKey = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No se encontró ninguna clave"))
        }
        
        // Obtener el contenido del primer objeto
        let innerContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: firstKey)
        
        // Buscar el valor USD
        guard let usdValue = try? innerContainer.decode(Double.self, forKey: DynamicCodingKeys(stringValue: "usd")!) else {
            throw DecodingError.keyNotFound(DynamicCodingKeys(stringValue: "usd")!,
                .init(codingPath: [], debugDescription: "No se encontró el precio USD"))
        }
        
        self.price = usdValue
    }
    
    // Claves dinámicas para decodificación
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
}

// MARK: - Sync Manual de Precios View
struct CryptoSyncView: View {
    // Debug Mode
    static let isDebugMode = false  // Cambiar a false para modo producción
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \CryptoSyncConfig.syncUrl) private var syncConfigs: [CryptoSyncConfig]
    
    @State private var logEntries: [SyncLogEntry] = []
    @State private var isSyncing = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Lista de configuraciones
            List {
                ForEach(cryptos) { crypto in
                    CryptoSyncRowView(
                        crypto: crypto,
                        syncConfig: syncConfigs.first { $0.crypto?.id == crypto.id },
                        onSave: { url, defaultPrice in
                            saveSyncConfig(for: crypto, url: url, defaultPrice: defaultPrice)
                        }
                    )
                }
            }
            
            // Botón de sincronización
            Button(action: startSync) {
                if isSyncing {
                    ProgressView()
                        .padding(.trailing, 8)
                } else {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Iniciar Sincronización")
                    }
                }
            }
            .disabled(isSyncing)
            .buttonStyle(.borderedProminent)
            .padding()
            
            // Log de sincronización
            VStack(alignment: .leading) {
                Text("Log de Sincronización")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(logEntries) { entry in
                            HStack(spacing: 8) {
                                Image(systemName: entry.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(entry.isError ? .red : .green)
                                
                                VStack(alignment: .leading) {
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(entry.cryptoSymbol): \(entry.message)")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
                .frame(height: 200)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .navigationTitle("Sync Manual de Precios")
    }
    
    private func saveSyncConfig(for crypto: Crypto, url: String, defaultPrice: Decimal) {
        if let existingConfig = syncConfigs.first(where: { $0.crypto?.id == crypto.id }) {
            existingConfig.syncUrl = url
            existingConfig.defaultPrice = defaultPrice
        } else {
            let newConfig = CryptoSyncConfig(crypto: crypto, syncUrl: url, defaultPrice: defaultPrice)
            modelContext.insert(newConfig)
        }
    }
    
    private func startSync() {
        isSyncing = true
        logEntries.removeAll()
        
        Task {
            for config in syncConfigs {
                guard let crypto = config.crypto else { continue }
                
                do {
                    if Self.isDebugMode {
                        // Modo Debug - Simulación de sincronización
                        await MainActor.run {
                            logEntries.insert(
                                SyncLogEntry(
                                    timestamp: Date(),
                                    cryptoSymbol: crypto.simbolo,
                                    message: "[DEBUG] Simulando sincronización con URL: \(config.syncUrl)",
                                    isError: false
                                ),
                                at: 0
                            )
                            
                            // Simular un precio nuevo (precio actual + 10%)
                            let precioSimulado = crypto.precio * Decimal(1.1)
                            
                            logEntries.insert(
                                SyncLogEntry(
                                    timestamp: Date(),
                                    cryptoSymbol: crypto.simbolo,
                                    message: "[DEBUG] Precio simulado: $\(precioSimulado) (actual: $\(crypto.precio))",
                                    isError: false
                                ),
                                at: 0
                            )
                        }
                        
                        // Simular delay de red
                        try await Task.sleep(nanoseconds: 500_000_000)
                        
                    } else {
                        // Configurar la sesión con configuraciones específicas para Sandbox
                        let configuration = URLSessionConfiguration.default
                        configuration.timeoutIntervalForRequest = 30
                        configuration.timeoutIntervalForResource = 30
                        configuration.waitsForConnectivity = true
                        configuration.allowsCellularAccess = true
                        configuration.allowsConstrainedNetworkAccess = true
                        configuration.allowsExpensiveNetworkAccess = true
                        
                        // Configurar explícitamente el DNS
                        configuration.urlCache = nil
                        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                        
                        let urlSession = URLSession(configuration: configuration)
                        
                        // Crear la solicitud con configuraciones específicas
                        guard let url = URL(string: config.syncUrl) else {
                            throw URLError(.badURL)
                        }
                        
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 30
                        request.networkServiceType = .default
                        request.allowsCellularAccess = true
                        request.allowsConstrainedNetworkAccess = true
                        request.allowsExpensiveNetworkAccess = true
                        
                        // Agregar entrada al log indicando inicio de solicitud
                        await MainActor.run {
                            logEntries.insert(
                                SyncLogEntry(
                                    timestamp: Date(),
                                    cryptoSymbol: crypto.simbolo,
                                    message: "Iniciando solicitud a: \(url.absoluteString)",
                                    isError: false
                                ),
                                at: 0
                            )
                        }
                        
                        let (data, urlResponse) = try await urlSession.data(for: request)
                        
                        guard let httpResponse = urlResponse as? HTTPURLResponse else {
                            throw URLError(.badServerResponse)
                        }
                        
                        // Verificar el código de respuesta HTTP
                        guard (200...299).contains(httpResponse.statusCode) else {
                            throw NSError(
                                domain: "HTTPError",
                                code: httpResponse.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "Error HTTP: \(httpResponse.statusCode)"]
                            )
                        }
                        
                        // Agregar entrada al log con la respuesta recibida
                        await MainActor.run {
                            logEntries.insert(
                                SyncLogEntry(
                                    timestamp: Date(),
                                    cryptoSymbol: crypto.simbolo,
                                    message: "Respuesta recibida (HTTP \(httpResponse.statusCode))",
                                    isError: false
                                ),
                                at: 0
                            )
                        }
                        
                        // Intentar decodificar la respuesta
                        let priceResponse = try JSONDecoder().decode(PriceResponse.self, from: data)
                        
                        // Usar el precio encontrado
                        await MainActor.run {
                            // Guardar el precio anterior en el histórico
                            let precioHistorico = PrecioHistorico(
                                crypto: crypto,
                                precio: crypto.precio,
                                fecha: crypto.ultimaActualizacion
                            )
                            modelContext.insert(precioHistorico)
                            
                            // Actualizar el precio actual
                            crypto.precio = Decimal(priceResponse.price)
                            crypto.ultimaActualizacion = Date()
                            
                            logEntries.insert(
                                SyncLogEntry(
                                    timestamp: Date(),
                                    cryptoSymbol: crypto.simbolo,
                                    message: "Precio actualizado: $\(priceResponse.price) (anterior: $\(precioHistorico.precio))",
                                    isError: false
                                ),
                                at: 0
                            )
                        }
                    }
                }   catch {
                    await MainActor.run {
                        if !Self.isDebugMode {
                            crypto.precio = config.defaultPrice
                            crypto.ultimaActualizacion = Date()
                        }
                        
                        let errorMessage = switch error {
                            case URLError.secureConnectionFailed:
                                "Error de conexión segura - Verifica que la URL use HTTPS"
                            case URLError.serverCertificateUntrusted:
                                "Certificado del servidor no confiable"
                            case URLError.networkConnectionLost:
                                "Se perdió la conexión de red"
                            case URLError.badURL:
                                "URL inválida: \(config.syncUrl)"
                            case URLError.cannotConnectToHost:
                                "No se puede conectar al servidor. URL: \(config.syncUrl)"
                            case URLError.timedOut:
                                "Tiempo de espera agotado después de 30 segundos"
                            case URLError.notConnectedToInternet:
                                "No hay conexión a internet. Verifica tu conexión de red"
                            case let decodingError as DecodingError:
                                switch decodingError {
                                    case let .keyNotFound(key, _):
                                        "Error al procesar respuesta: Falta la clave '\(key.stringValue)'"
                                    case let .valueNotFound(_, context):
                                        "Error al procesar respuesta: Valor no encontrado en \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                                    case let .typeMismatch(_, context):
                                        "Error al procesar respuesta: Tipo incorrecto en \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                                    case .dataCorrupted(_):
                                        "Error al procesar respuesta: Datos corruptos o formato inválido"
                                    @unknown default:
                                        "Error al procesar respuesta: \(decodingError.localizedDescription)"
                                }
                            case let httpError as NSError where httpError.domain == "HTTPError":
                                "Error del servidor (HTTP \(httpError.code))"
                            default:
                                "Error inesperado: \(error.localizedDescription) [\(type(of: error))]"
                        }
                        
                        logEntries.insert(
                            SyncLogEntry(
                                timestamp: Date(),
                                cryptoSymbol: crypto.simbolo,
                                message: "\(errorMessage). Usando precio por defecto (\(config.defaultPrice))",
                                isError: true
                            ),
                            at: 0
                        )
                    }
                }
                
                // Pequeña pausa entre solicitudes
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
            }
            
            await MainActor.run {
                isSyncing = false
                
                // Agregar mensaje final
                logEntries.insert(
                    SyncLogEntry(
                        timestamp: Date(),
                        cryptoSymbol: "Sistema",
                        message: Self.isDebugMode ?
                            "[DEBUG] Simulación de sincronización completada." :
                            "Sincronización completada. Se actualizaron los precios históricos.",
                        isError: false
                    ),
                    at: 0
                )
            }
        }
    }
}

// MARK: - Crypto Sync Row View
struct CryptoSyncRowView: View {
    let crypto: Crypto
    let syncConfig: CryptoSyncConfig?
    let onSave: (String, Decimal) -> Void
    
    @State private var syncUrl: String = ""
    @State private var defaultPrice: Decimal = 0
    @State private var isEditing = false
    @State private var showingHistory = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Crypto info
            HStack {
                Text(crypto.nombre)
                    .font(.headline)
                Text("(\(crypto.simbolo))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { isEditing.toggle() }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                        .foregroundStyle(isEditing ? .green : .blue)
                }
            }
            
            if isEditing {
                // Campos de edición
                TextField("URL de Sincronización", text: $syncUrl)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Precio por Default", value: $defaultPrice, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)
 
                Button("Guardar") {
                    onSave(syncUrl, defaultPrice)
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .disabled(syncUrl.isEmpty || defaultPrice <= 0)
            } else {
                // Vista de solo lectura
                if let config = syncConfig {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("URL: \(config.syncUrl)")
                                .font(.caption)
                            Text("Precio Default: \(config.defaultPrice.formatted(.currency(code: "USD")))")
                                .font(.caption)
                        }
                        Spacer()
                        CryptoHistoryButton(crypto: crypto, showingHistory: $showingHistory)
                            .font(.caption)
                    }
                } else {
                    Text("Sin configuración")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if let config = syncConfig {
                syncUrl = config.syncUrl
                defaultPrice = config.defaultPrice
            }
        }
    }
}

#Preview {
    NavigationStack {
        CryptoSyncView()
    }
}
