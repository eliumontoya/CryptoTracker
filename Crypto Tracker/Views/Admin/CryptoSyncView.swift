import SwiftData
import SwiftUI

struct CryptoSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CryptoSyncViewModel
    
    init() {
        // Initialize using the default model container
        let container = try! ModelContainer(for: Crypto.self)
        let context = ModelContext(container)
        _viewModel = StateObject(wrappedValue: CryptoSyncViewModel(modelContext: context))
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
            // Configurar limpieza cuando la vista se desmonte
            try? await Task.sleep(nanoseconds: 1_000_000) // Pequeña pausa para asegurar inicialización
            Task { @MainActor in
                for await _ in NotificationCenter.default.notifications(named: NSWindow.willCloseNotification) {
                    await viewModel.cleanup()
                }
            }
        }
    }
} 
