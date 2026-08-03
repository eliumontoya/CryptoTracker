import SwiftUI
import SwiftData

// MARK: - Crypto Sync Row View
struct CryptoSyncRowView: View {
    let crypto: Crypto
    let syncConfig: CryptoSyncConfig?
    let onSave: (String, Decimal) -> Void

    @State private var coingeckoId: String = ""
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
                TextField("CoinGecko ID", text: $coingeckoId)
                    .textFieldStyle(.roundedBorder)

                TextField("Precio por Default", value: $defaultPrice, format: .currency(code: "USD"))
                    .textFieldStyle(.roundedBorder)

                Button("Guardar") {
                    onSave(coingeckoId, defaultPrice)
                    isEditing = false
                }
                .buttonStyle(.bordered)
                .disabled(coingeckoId.isEmpty || defaultPrice <= 0)
            } else {
                // Vista de solo lectura
                HStack {
                    VStack(alignment: .leading) {
                        Text("CoinGecko ID: \(crypto.coingeckoId ?? "-")")
                            .font(.caption)
                        if let config = syncConfig {
                            Text("Precio Default: \(Format.usd(config.defaultPrice))")
                                .font(.caption)
                        }
                    }
                    Spacer()
                    CryptoHistoryButton(crypto: crypto, showingHistory: $showingHistory)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            coingeckoId = crypto.coingeckoId ?? ""
            if let config = syncConfig {
                defaultPrice = config.defaultPrice
            }
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
