import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol SnapshotService: AnyObject {
    func recordDailySnapshot(for portfolioId: UUID, in context: ModelContext) async throws
    func fetchSnapshots(for portfolioId: UUID, in context: ModelContext) -> [PortfolioSnapshot]
}

// MARK: - SwiftData Implementation

@MainActor
final class SwiftDataSnapshotService: SnapshotService {
    func recordDailySnapshot(for portfolioId: UUID, in context: ModelContext) async throws {
        let today = Calendar.current.startOfDay(for: Date())

        let descriptor = FetchDescriptor<PortfolioSnapshot>(
            predicate: #Predicate {
                $0.portfolioId == portfolioId && $0.date >= today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let existing = (try? context.fetch(descriptor)) ?? []
        let summary = PortfolioQueries.portfolioSummary(portfolioId: portfolioId, in: context)

        if let snapshot = existing.first {
            snapshot.totalUSD = summary.valorActualUSD
        } else {
            let snapshot = PortfolioSnapshot(
                date: today,
                totalUSD: summary.valorActualUSD,
                portfolioId: portfolioId
            )
            context.insert(snapshot)
        }

        try context.save()
        try await pruneSnapshots(for: portfolioId, in: context)
    }

    func fetchSnapshots(for portfolioId: UUID, in context: ModelContext) -> [PortfolioSnapshot] {
        let descriptor = FetchDescriptor<PortfolioSnapshot>(
            predicate: #Predicate { $0.portfolioId == portfolioId },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func pruneSnapshots(for portfolioId: UUID, in context: ModelContext) async throws {
        let descriptor = FetchDescriptor<PortfolioSnapshot>(
            predicate: #Predicate { $0.portfolioId == portfolioId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let snapshots = (try? context.fetch(descriptor)) ?? []
        guard snapshots.count > 365 else { return }

        let toDelete = snapshots.dropFirst(365)
        for snapshot in toDelete {
            context.delete(snapshot)
        }
        try context.save()
    }
}
