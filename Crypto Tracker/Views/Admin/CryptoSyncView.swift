import SwiftData
import SwiftUI

struct CryptoSyncView: View {
    @StateObject private var viewModel: CryptoSyncViewModel
    
    init(viewModel: CryptoSyncViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
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
            try? await Task.sleep(nanoseconds: 1_000_000)
            #if os(macOS)
            Task { @MainActor in
                for await _ in NotificationCenter.default.notifications(named: NSWindow.willCloseNotification) {
                    await viewModel.cleanup()
                }
            }
            #endif
        }
    }
} 
