import XCTest
import SwiftData
@testable import Crypto_Tracker

@MainActor
final class BackupViewModelTests: XCTestCase {
    private var modelContext: ModelContext!
    private var backupService: BackupService!
    private var viewModel: BackupViewModel!

    override func setUp() {
        super.setUp()
        modelContext = TestSetup.createModelContext()
        backupService = JSONBackupService()
        viewModel = BackupViewModel(modelContext: modelContext, backupService: backupService)
    }

    override func tearDown() {
        viewModel = nil
        backupService = nil
        modelContext = nil
        super.tearDown()
    }

    func testPrepareExportProducesDocument() {
        viewModel.prepareExport()
        XCTAssertNotNil(viewModel.exportData)
        XCTAssertTrue(viewModel.isExporting)
    }

    func testPrepareExportSetsErrorOnFailure() {
        let failingService = FailingBackupService()
        let viewModel = BackupViewModel(modelContext: modelContext, backupService: failingService)
        viewModel.prepareExport()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.exportData)
    }

    func testHandleImportRestoresData() throws {
        let portfolio = Portfolio(nombre: "Principal", descripcion: "", isDefault: true)
        let cartera = Cartera(nombre: "Binance", simbolo: "BNB", portfolio: portfolio)
        let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 50000)
        modelContext.insert(portfolio)
        modelContext.insert(cartera)
        modelContext.insert(crypto)
        try modelContext.save()

        let data = try backupService.export(in: modelContext)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("backup.json")
        try data.write(to: tempURL)

        // Clear context before restore
        try modelContext.fetch(FetchDescriptor<Crypto>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<Cartera>()).forEach(modelContext.delete)
        try modelContext.fetch(FetchDescriptor<Portfolio>()).forEach(modelContext.delete)
        try modelContext.save()
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<Crypto>()).count, 0)

        viewModel.handleImport(url: tempURL)

        XCTAssertEqual(viewModel.importResult, .success)
        XCTAssertEqual(try modelContext.fetch(FetchDescriptor<Crypto>()).count, 1)
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testHandleImportReportsFailure() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("invalid.json")
        let invalidData = Data("not json".utf8)
        try? invalidData.write(to: tempURL)

        viewModel.handleImport(url: tempURL)

        if case .failure = viewModel.importResult {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected failure import result")
        }
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testDismissImportResultClearsResult() {
        viewModel.importResult = .success
        viewModel.dismissImportResult()
        XCTAssertNil(viewModel.importResult)
    }
}

final class FailingBackupService: BackupService {
    func export(in context: ModelContext) throws -> Data {
        throw BackupError.unsupportedVersion
    }

    func restore(from data: Data, in context: ModelContext) throws {
        throw BackupError.unsupportedVersion
    }
}
