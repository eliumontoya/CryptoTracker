import Foundation
import SwiftData

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var summary: MainPortfolioSummary?
    @Published private(set) var distribution: [MainCryptoDistribution] = []
    @Published private(set) var snapshots: [PortfolioSnapshot] = []

    private let modelContext: ModelContext
    private let snapshotService: SnapshotService

    init(
        modelContext: ModelContext,
        snapshotService: SnapshotService? = nil
    ) {
        self.modelContext = modelContext
        self.snapshotService = snapshotService ?? SwiftDataSnapshotService()
    }

    func loadPortfolio() {
        guard let portfolio = PortfolioQueries.defaultPortfolio(in: modelContext) else { return }

        summary = MainPortfolioCalculator.calcularResumen(
            portfolioId: portfolio.id,
            in: modelContext
        )

        distribution = MainPortfolioCalculator.calcularDistribucionGanancias(
            portfolioId: portfolio.id,
            in: modelContext
        )

        snapshots = snapshotService.fetchSnapshots(for: portfolio.id, in: modelContext)

        Task {
            try? await snapshotService.recordDailySnapshot(for: portfolio.id, in: modelContext)
            await MainActor.run {
                self.snapshots = snapshotService.fetchSnapshots(for: portfolio.id, in: modelContext)
            }
        }
    }

    func clear() {
        summary = nil
        distribution = []
        snapshots = []
    }
}
