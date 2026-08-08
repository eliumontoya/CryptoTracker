import Foundation
import SwiftData

// MARK: - Protocol

/// Runs a persistence block atomically: the block mutates the `ModelContext`,
/// and `save()` is called only when the block completes without throwing.
/// If the block (or the save) throws, nothing is persisted and the error propagates.
@MainActor
protocol TransactionRunner {
    func run<T>(_ block: (ModelContext) throws -> T) async throws -> T
}

// MARK: - Implementation

/// Default `TransactionRunner` backed by SwiftData's atomic `ModelContext.save()`.
/// Inject a single `ModelContext` per runner; do not share the runner across contexts.
@MainActor
struct ModelContextTransactionRunner: TransactionRunner {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func run<T>(_ block: (ModelContext) throws -> T) async throws -> T {
        do {
            let result = try block(modelContext)
            try modelContext.save()
            return result
        } catch {
            // Discard any pending inserts/deletes so a later save() cannot
            // persist a partial write (movement without its holding update).
            modelContext.rollback()
            throw error
        }
    }
}
