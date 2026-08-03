import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class BackupViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var exportData: BackupDocument?
    @Published var importResult: BackupResult?
    @Published var errorMessage: String?

    private let modelContext: ModelContext
    private let backupService: BackupService

    init(
        modelContext: ModelContext,
        backupService: BackupService
    ) {
        self.modelContext = modelContext
        self.backupService = backupService
    }

    func prepareExport() {
        do {
            let data = try backupService.export(in: modelContext)
            exportData = BackupDocument(data: data)
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleImport(url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw BackupError.unsupportedVersion
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            try backupService.restore(from: data, in: modelContext)
            importResult = .success
        } catch {
            importResult = .failure(error.localizedDescription)
        }
    }

    func dismissImportResult() {
        importResult = nil
    }
}

enum BackupResult: Equatable {
    case success
    case failure(String)
}

struct BackupDocument: FileDocument {
    let data: Data

    static var readableContentTypes: [UTType] { [.json] }

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
