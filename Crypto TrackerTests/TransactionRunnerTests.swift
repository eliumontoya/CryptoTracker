import Foundation
import SwiftData
import Testing
@testable import Crypto_Tracker

@MainActor
struct TransactionRunnerTests {
    private func makeRunner() -> ModelContextTransactionRunner {
        ModelContextTransactionRunner(modelContext: TestSetup.createModelContext())
    }

    @Test func runReturnsBlockResult() async throws {
        let runner = makeRunner()

        let value = try await runner.run { _ in 42 }
        #expect(value == 42)
    }

    @Test func runPersistsMutationsOnSuccess() async throws {
        let runner = makeRunner()
        let crypto = Crypto.mock(precio: 50_000)

        let inserted = try await runner.run { ctx in
            ctx.insert(crypto)
            return crypto
        }

        #expect(inserted.id == crypto.id)
        let count = try await runner.run { ctx in
            try ctx.fetchCount(FetchDescriptor<Crypto>())
        }
        #expect(count == 1)
    }

    @Test func runRollsBackBlockWhenBlockThrows() async throws {
        struct BlockError: Error {}
        let runner = makeRunner()
        let crypto = Crypto.mock(precio: 50_000)

        do {
            _ = try await runner.run { ctx in
                ctx.insert(crypto)
                throw BlockError()
            }
            Issue.record("Expected run to throw")
        } catch is BlockError {
            // Expected: block error propagates and nothing is persisted.
        }

        let count = try await runner.run { ctx in
            try ctx.fetchCount(FetchDescriptor<Crypto>())
        }
        #expect(count == 0)
    }
}
