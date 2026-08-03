import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel

    init(viewModel: BackupViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.clockwise.icloud")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Backup & Restore")
                .font(.title)
                .bold()

            Text("Export your portfolio data as JSON for safekeeping, or restore a previously exported backup.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 16) {
                Button(action: { viewModel.prepareExport() }) {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.borderedProminent)

                Button(action: { viewModel.isImporting = true }) {
                    Label("Import Backup", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: 300)
                }
                .buttonStyle(.bordered)
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Backup")
        .fileExporter(
            isPresented: $viewModel.isExporting,
            document: viewModel.exportData,
            contentType: .json,
            defaultFilename: "CryptoTrackerBackup"
        ) { result in
            switch result {
            case .success:
                viewModel.exportData = nil
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.handleImport(url: url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Import", isPresented: Binding(
            get: { viewModel.importResult != nil },
            set: { if !$0 { viewModel.dismissImportResult() } }
        )) {
            Button("OK", role: .cancel) { viewModel.dismissImportResult() }
        } message: {
            switch viewModel.importResult {
            case .success:
                Text("Backup restored successfully.")
            case .failure(let message):
                Text("Restore failed: \(message)")
            case .none:
                Text("")
            }
        }
    }
}
