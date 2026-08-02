import Foundation
import SwiftData

// MARK: - Errors

/// Errors thrown by `DeleteMovementUseCase`. The use case supports entry, exit,
/// wallet-transfer, and swap movements; the revert formula for other types differs.
enum DeleteMovementError: LocalizedError, Equatable {
    case unsupportedMovementType(TipoMovimiento)
    case insufficientHoldings
    case missingPairedMovement

    var errorDescription: String? {
        switch self {
        case .unsupportedMovementType(let tipo):
            return "Only entry, exit, transfer, and swap movements can be deleted. Received type: \(tipo.title)."
        case .insufficientHoldings:
            return "Cannot delete the movement: reverting it would leave the wallet balance negative."
        case .missingPairedMovement:
            return "Cannot delete the paired movement: the paired leg could not be found."
        }
    }
}

// MARK: - Protocol

/// Physically deletes an entry, exit, wallet-transfer, or swap movement and reverts
/// its holding effect atomically. For paired movements, both legs are deleted together.
protocol DeleteMovementUseCaseProtocol {
    func delete(_ movement: Movimiento) async throws
}

// MARK: - Implementation

/// Deletes a movement and its holding effect in one `TransactionRunner` block:
/// 1. Pre-validates that reverting the movement's effect keeps the materialized
///    `Holding` non-negative (domain invariant, issue #39).
/// 2. Reverts the holding via `HoldingServiceProtocol.deleteHoldingForMovement`.
/// 3. Physically deletes the movement (`context.delete`).
///
/// For transfers, both legs are resolved by `groupId` and deleted/reverted in the
/// same transaction.
///
/// Any failure rolls back the whole block, so movement + holding stay consistent.
struct DeleteMovementUseCase: DeleteMovementUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    func delete(_ movement: Movimiento) async throws {
        switch movement.tipo {
        case .entrada, .salida:
            try await deleteSingle(movement)
        case .transferenciaSalida, .transferenciaEntrada:
            try await deleteTransfer(movement)
        case .swapSalida, .swapEntrada:
            try await deleteSwap(movement)
        default:
            throw DeleteMovementError.unsupportedMovementType(movement.tipo)
        }
    }

    // MARK: - Single-leg delete

    private func deleteSingle(_ movement: Movimiento) async throws {
        try await transactionRunner.run { context in
            try validateSingleRevert(of: movement, in: context)
            try holdingService.deleteHoldingForMovement(movement, in: context)
            context.delete(movement)
        }
    }

    // MARK: - Transfer delete

    private func deleteTransfer(_ movement: Movimiento) async throws {
        try await transactionRunner.run { context in
            guard let paired = try pairedTransferMovement(for: movement, in: context) else {
                throw DeleteMovementError.missingPairedMovement
            }
            let entrada = movement.tipo == .transferenciaEntrada ? movement : paired
            let salida = movement.tipo == .transferenciaSalida ? movement : paired

            try validateTransferRevert(salida: salida, entrada: entrada, in: context)
            try holdingService.deleteHoldingForMovement(salida, in: context)
            try holdingService.deleteHoldingForMovement(entrada, in: context)
            context.delete(salida)
            context.delete(entrada)
        }
    }

    // MARK: - Swap delete

    private func deleteSwap(_ movement: Movimiento) async throws {
        try await transactionRunner.run { context in
            guard let paired = try pairedSwapMovement(for: movement, in: context) else {
                throw DeleteMovementError.missingPairedMovement
            }
            let entrada = movement.tipo == .swapEntrada ? movement : paired
            let salida = movement.tipo == .swapSalida ? movement : paired

            try validateSwapRevert(salida: salida, entrada: entrada, in: context)
            try holdingService.deleteHoldingForMovement(salida, in: context)
            try holdingService.deleteHoldingForMovement(entrada, in: context)
            context.delete(salida)
            context.delete(entrada)
        }
    }

    // MARK: - Validation

    /// Reject deletes that would drive any affected holding below zero.
    ///
    /// For an `.entrada` the revert subtracts `cantidadCrypto` from the current
    /// holding, so the current row must cover it. `Holding.cantidad` clamps at 0
    /// via `didSet`, hence the guard must run BEFORE the revert to surface the
    /// violation as an error instead of silently erasing the row.
    ///
    /// For a `.salida` the revert adds `cantidadCrypto` back to the holding,
    /// which can never make the balance negative.
    private func validateSingleRevert(of movement: Movimiento, in context: ModelContext) throws {
        // Legacy wallets without a portfolio cannot own a materialized holding
        // (mirrors `HoldingService.apply`'s guard) — nothing to validate.
        guard movement.cartera?.portfolio != nil || PortfolioQueries.defaultPortfolio(in: context) != nil else {
            return
        }
        guard movement.tipo == .entrada else { return }
        let current = try holdingRow(for: movement, in: context)?.cantidad ?? 0
        guard current - movement.cantidadCrypto >= 0 else {
            throw DeleteMovementError.insufficientHoldings
        }
    }

    /// For a transfer, the only revert that can drive a holding negative is the
    /// entrada leg: it subtracts `cantidadCryptoEntrada` from the destination
    /// wallet. The salida revert always adds funds back to the origin wallet.
    private func validateTransferRevert(
        salida: Movimiento,
        entrada: Movimiento,
        in context: ModelContext
    ) throws {
        guard entrada.cartera?.portfolio != nil || PortfolioQueries.defaultPortfolio(in: context) != nil else {
            return
        }
        let current = try holdingRow(for: entrada, in: context)?.cantidad ?? 0
        guard current - entrada.cantidadCryptoEntrada >= 0 else {
            throw DeleteMovementError.insufficientHoldings
        }
    }

    /// For a swap, the only revert that can drive a holding negative is the
    /// entrada leg: it subtracts `cantidadDestino` of the destination crypto from
    /// the wallet. The salida revert always adds funds back to the origin crypto.
    private func validateSwapRevert(
        salida: Movimiento,
        entrada: Movimiento,
        in context: ModelContext
    ) throws {
        guard let cartera = entrada.cartera,
              let crypto = entrada.cryptoDestino,
              cartera.portfolio != nil || PortfolioQueries.defaultPortfolio(in: context) != nil else {
            return
        }
        let current = try holdingRow(cartera: cartera, crypto: crypto, in: context)?.cantidad ?? 0
        guard current - entrada.cantidadDestino >= 0 else {
            throw DeleteMovementError.insufficientHoldings
        }
    }

    // MARK: - Lookups

    private func holdingRow(for movement: Movimiento, in context: ModelContext) throws -> Holding? {
        guard let cartera = movement.cartera, let crypto = movement.crypto else { return nil }
        return try holdingRow(cartera: cartera, crypto: crypto, in: context)
    }

    private func holdingRow(cartera: Cartera, crypto: Crypto, in context: ModelContext) throws -> Holding? {
        guard let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else { return nil }
        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        return try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first
    }

    private func pairedTransferMovement(for movement: Movimiento, in context: ModelContext) throws -> Movimiento? {
        guard let groupId = movement.groupId else { return nil }
        let expectedTipo = movement.tipo == .transferenciaSalida ? "transferenciaEntrada" : "transferenciaSalida"
        return try context.fetch(
            FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.groupId == groupId && $0.tipoRaw == expectedTipo }
            )
        ).first
    }

    private func pairedSwapMovement(for movement: Movimiento, in context: ModelContext) throws -> Movimiento? {
        guard let groupId = movement.groupId else { return nil }
        let expectedTipo = movement.tipo == .swapSalida ? "swapEntrada" : "swapSalida"
        return try context.fetch(
            FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.groupId == groupId && $0.tipoRaw == expectedTipo }
            )
        ).first
    }
}
