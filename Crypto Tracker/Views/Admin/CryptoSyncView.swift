// MARK: - CryptoSyncConfig Model
import SwiftData
import SwiftUI
 



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


struct CryptoSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CryptoSyncViewModel
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: CryptoSyncViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Lista de configuraciones
            List {
                ForEach(viewModel.state.cryptos) { crypto in
                    CryptoSyncRowView(
                        crypto: crypto,
                        syncConfig: viewModel.getSyncConfig(for: crypto.id),
                        onSave: { url, defaultPrice in
                            viewModel.saveSyncConfig(for: crypto, url: url, defaultPrice: defaultPrice)
                        }
                    )
                }
            }
            
            // Botón de sincronización
            Button(action: { viewModel.startSync() }) {
                if viewModel.state.isSyncing {
                    ProgressView()
                        .padding(.trailing, 8)
                } else {
                    Label("Iniciar Sincronización", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(viewModel.state.isSyncing)
            .buttonStyle(.borderedProminent)
            .padding()
            
            // Log de sincronización
            SyncLogView(logEntries: viewModel.state.logEntries)
        }
        .padding()
        .navigationTitle("Sync Manual de Precios")
        .onAppear {
            viewModel.loadData()
        }
 
        .task {
                    // Asegurar que se limpie cuando la vista se desmonte
            await viewModel.cleanup()
                }
    }
}

// MARK: - Log View Component
struct SyncLogView: View {
    let logEntries: [SyncLogEntry]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Log de Sincronización")
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(logEntries) { entry in
                        LogEntryRow(entry: entry)
                    }
                }
                .padding()
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Log Entry Row Component
struct LogEntryRow: View {
    let entry: SyncLogEntry
    
    var body: some View {
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
