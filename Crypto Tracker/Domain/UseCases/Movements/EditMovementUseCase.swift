import Foundation
import SwiftData

// MARK: - Values

/// Editable fields of an entry or exit movement (`.entrada` / `.salida`). A value
/// payload is used so the use case can persist every field the form exposes
/// without the caller reaching into the entity.
struct EditMovementValues {
    let fecha: Date
    let cantidadCrypto: Decimal
    let precioUSD: Decimal
    let valorTotalUSD: Decimal
    let usaFiatAlterno: Bool
    let precioFiatAlterno: Decimal?
    let valorTotalFiatAlterno: Decimal?
    let crypto: Crypto
    let cartera: Cartera
    let fiatAlterno: FIAT?
}

// MARK: - Input

/// Input for editing an existing entry or exit movement.
///
/// Contract: `movement` MUST still hold the pre-edit values when `execute` is
/// called — the use case snapshots them (`HoldingServiceProtocol.snapshot`) as
/// the revert basis, so any earlier mutation of the entity would corrupt the
/// holding adjustment.
struct EditMovementInput {
    let movement: Movimiento
    let updated: EditMovementValues
}

/// Values for editing an existing wallet-to-wallet transfer pair.
struct EditTransferMovementValues {
    let fecha: Date
    let cantidadCryptoSalida: Decimal
    let cantidadCryptoEntrada: Decimal
    let crypto: Crypto
    let carteraOrigen: Cartera
    let carteraDestino: Cartera
}

/// Input for editing an existing transfer pair.
///
/// `salida` is the `.transferenciaSalida` leg; the use case resolves the paired
/// `.transferenciaEntrada` by `groupId`.
struct EditTransferMovementInput {
    let salida: Movimiento
    let updated: EditTransferMovementValues
}

/// Values for editing an existing swap pair.
struct EditSwapMovementValues {
    let fecha: Date
    let cantidadOrigen: Decimal
    let cantidadDestino: Decimal
    let precioUSDOrigen: Decimal
    let precioUSDDestino: Decimal
    let cartera: Cartera
    let cryptoOrigen: Crypto
    let cryptoDestino: Crypto
}

/// Input for editing an existing swap pair.
///
/// `salida` is the `.swapSalida` leg; the use case resolves the paired
/// `.swapEntrada` by `groupId`.
struct EditSwapMovementInput {
    let salida: Movimiento
    let updated: EditSwapMovementValues
}

// MARK: - Error

/// Domain errors for entry/exit movement editing.
enum EditMovementError: Error, LocalizedError {
    /// The edit would drive a wallet holding below zero.
    case insufficientHoldings
    /// The use case only supports `.entrada` and `.salida` movements.
    case unsupportedMovementType
    /// A transfer edit was requested but the paired leg could not be found.
    case missingPairedMovement

    var errorDescription: String? {
        switch self {
        case .insufficientHoldings:
            return "La edición dejaría la cartera con saldo negativo"
        case .unsupportedMovementType:
            return "Este tipo de movimiento no se puede editar como entrada o salida"
        case .missingPairedMovement:
            return "No se encontró la pierna de entrada emparejada de la transferencia"
        }
    }
}

// MARK: - Protocol

/// Edits an existing entry or exit movement and adjusts the associated holding
/// in one atomic transaction: the previous holding effect is reverted and the
/// new one applied, so the materialized `Holding` rows stay in sync with the
/// movement.
protocol EditMovementUseCaseProtocol {
    func execute(_ input: EditMovementInput) async throws

    /// Edits an existing wallet-to-wallet transfer pair (`transferenciaSalida` +
    /// `transferenciaEntrada`) atomically, adjusting both affected holdings.
    func execute(_ input: EditTransferMovementInput) async throws

    /// Edits an existing swap pair (`swapSalida` + `swapEntrada`) atomically,
    /// adjusting both affected holdings.
    func execute(_ input: EditSwapMovementInput) async throws
}

// MARK: - Implementation

struct EditMovementUseCase: EditMovementUseCaseProtocol {
    private let transactionRunner: TransactionRunner
    private let holdingService: HoldingServiceProtocol

    init(transactionRunner: TransactionRunner, holdingService: HoldingServiceProtocol) {
        self.transactionRunner = transactionRunner
        self.holdingService = holdingService
    }

    func execute(_ input: EditMovementInput) async throws {
        // Old state: snapshot BEFORE mutation so the edit can revert the
        // previously applied holding effect and apply the new one.
        let previous = holdingService.snapshot(of: input.movement)

        try await transactionRunner.run { context in
            try validateEdit(previous: previous, updated: input.updated, in: context)
            apply(input.updated, to: input.movement)
            try holdingService.updateHoldingForMovement(input.movement, previous: previous, in: context)
        }
    }

    func execute(_ input: EditTransferMovementInput) async throws {
        let previousSalida = holdingService.snapshot(of: input.salida)
        try await transactionRunner.run { context in
            guard let entrada = try pairedTransferEntrada(for: input.salida, in: context) else {
                throw EditMovementError.missingPairedMovement
            }
            let previousEntrada = self.holdingService.snapshot(of: entrada)
            try validateTransferEdit(
                salida: input.salida,
                entrada: entrada,
                updated: input.updated,
                in: context
            )
            apply(input.updated, to: input.salida, entrada: entrada)
            try self.holdingService.updateHoldingForMovement(input.salida, previous: previousSalida, in: context)
            try self.holdingService.updateHoldingForMovement(entrada, previous: previousEntrada, in: context)
        }
    }

    func execute(_ input: EditSwapMovementInput) async throws {
        let previousSalida = holdingService.snapshot(of: input.salida)
        try await transactionRunner.run { context in
            guard let entrada = try pairedSwapEntrada(for: input.salida, in: context) else {
                throw EditMovementError.missingPairedMovement
            }
            let previousEntrada = self.holdingService.snapshot(of: entrada)
            try validateSwapEdit(
                salida: input.salida,
                entrada: entrada,
                updated: input.updated,
                in: context
            )
            apply(input.updated, to: input.salida, entrada: entrada)
            try self.holdingService.updateHoldingForMovement(input.salida, previous: previousSalida, in: context)
            try self.holdingService.updateHoldingForMovement(entrada, previous: previousEntrada, in: context)
        }
    }

    // MARK: - Mutation

    private func apply(_ values: EditMovementValues, to movement: Movimiento) {
        movement.fecha = values.fecha
        movement.cantidadCrypto = values.cantidadCrypto
        movement.precioUSD = values.precioUSD
        movement.valorTotalUSD = values.valorTotalUSD
        movement.usaFiatAlterno = values.usaFiatAlterno
        movement.precioFiatAlterno = values.precioFiatAlterno
        movement.valorTotalFiatAlterno = values.valorTotalFiatAlterno
        movement.cartera = values.cartera
        movement.crypto = values.crypto
        movement.fiatAlterno = values.fiatAlterno
    }

    private func apply(_ values: EditTransferMovementValues, to salida: Movimiento, entrada: Movimiento) {
        let comision = values.cantidadCryptoSalida - values.cantidadCryptoEntrada

        salida.fecha = values.fecha
        salida.cantidadCryptoSalida = values.cantidadCryptoSalida
        salida.cantidadCryptoEntrada = values.cantidadCryptoEntrada
        salida.cantidadCryptoComision = comision
        salida.crypto = values.crypto
        salida.cartera = values.carteraOrigen
        salida.carteraOrigen = values.carteraOrigen
        salida.carteraDestino = values.carteraDestino

        entrada.fecha = values.fecha
        entrada.cantidadCryptoSalida = values.cantidadCryptoSalida
        entrada.cantidadCryptoEntrada = values.cantidadCryptoEntrada
        entrada.cantidadCryptoComision = comision
        entrada.crypto = values.crypto
        entrada.cartera = values.carteraDestino
        entrada.carteraOrigen = values.carteraOrigen
        entrada.carteraDestino = values.carteraDestino
    }

    private func apply(_ values: EditSwapMovementValues, to salida: Movimiento, entrada: Movimiento) {
        salida.fecha = values.fecha
        salida.cantidadOrigen = values.cantidadOrigen
        salida.cantidadDestino = values.cantidadDestino
        salida.precioUSDOrigen = values.precioUSDOrigen
        salida.precioUSDDestino = values.precioUSDDestino
        salida.cartera = values.cartera
        salida.cryptoOrigen = values.cryptoOrigen
        salida.cryptoDestino = values.cryptoDestino

        entrada.fecha = values.fecha
        entrada.cantidadOrigen = values.cantidadOrigen
        entrada.cantidadDestino = values.cantidadDestino
        entrada.precioUSDOrigen = values.precioUSDOrigen
        entrada.precioUSDDestino = values.precioUSDDestino
        entrada.cartera = values.cartera
        entrada.cryptoOrigen = values.cryptoOrigen
        entrada.cryptoDestino = values.cryptoDestino
    }

    // MARK: - Validation

    /// Fails fast when the edit would drive any affected holding below zero.
    /// For `.entrada` only the revert can be unsafe (subtraction). For `.salida`
    /// the revert adds back funds, but the new exit must be covered by the
    /// destination wallet (same or different from the origin).
    private func validateEdit(previous: HoldingSnapshot, updated: EditMovementValues, in context: ModelContext) throws {
        switch previous.tipo {
        case .entrada:
            try validateEntradaRevert(previous: previous, in: context)
        case .salida:
            try validateSalidaEdit(previous: previous, updated: updated, in: context)
        default:
            throw EditMovementError.unsupportedMovementType
        }
    }

    /// For an `.entrada`, the revert subtracts the previous quantity from the
    /// holding it created. `Holding.cantidad` clamps silently at zero, so the
    /// use case fails fast with an explicit error instead of corrupting the
    /// balance (e.g. after later sales consumed the entry's holdings).
    private func validateEntradaRevert(previous: HoldingSnapshot, in context: ModelContext) throws {
        guard let cartera = try fetchCartera(id: previous.carteraId, in: context),
              let crypto = try fetchCrypto(id: previous.cryptoId, in: context) else { return }
        // Legacy wallets without a portfolio cannot own a materialized holding row.
        guard let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else { return }

        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        guard let holding = try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first else { return }

        guard holding.cantidad - previous.cantidadCrypto >= 0 else {
            throw EditMovementError.insufficientHoldings
        }
    }

    /// For a `.salida` the origin holding gets the old quantity back, then the
    /// new exit is applied. If the wallet or crypto changed, the new exit is
    /// taken from a different destination holding, which must have enough funds.
    private func validateSalidaEdit(previous: HoldingSnapshot, updated: EditMovementValues, in context: ModelContext) throws {
        let destinationChanged = previous.carteraId != updated.cartera.id || previous.cryptoId != updated.crypto.id

        if destinationChanged {
            // Revert origin is always safe (adds back). Validate destination can
            // cover the new exit quantity.
            try validateSalidaDestination(cartera: updated.cartera, crypto: updated.crypto, quantity: updated.cantidadCrypto, in: context)
        } else {
            try validateSalidaSameDestination(previous: previous, updated: updated, in: context)
        }
    }

    private func validateSalidaSameDestination(previous: HoldingSnapshot, updated: EditMovementValues, in context: ModelContext) throws {
        guard let cartera = try fetchCartera(id: previous.carteraId, in: context),
              let crypto = try fetchCrypto(id: previous.cryptoId, in: context) else { return }
        guard let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else { return }

        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        guard let holding = try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first else {
            // No holding row means zero available balance; any exit is invalid.
            throw EditMovementError.insufficientHoldings
        }

        guard holding.cantidad + previous.cantidadCrypto - updated.cantidadCrypto >= 0 else {
            throw EditMovementError.insufficientHoldings
        }
    }

    private func validateSalidaDestination(cartera: Cartera, crypto: Crypto, quantity: Decimal, in context: ModelContext) throws {
        guard let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else {
            // Legacy wallets without a portfolio cannot own a materialized holding row.
            return
        }

        let key = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        guard let holding = try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == key })
        ).first else {
            throw EditMovementError.insufficientHoldings
        }

        guard holding.cantidad >= quantity else {
            throw EditMovementError.insufficientHoldings
        }
    }

    // MARK: - Transfer validation

    /// Projects the balance for every affected `(portfolio, cartera, crypto)` key
    /// after reverting the old transfer pair and applying the new one. Fails fast
    /// if any key would go negative.
    private func validateTransferEdit(
        salida: Movimiento,
        entrada: Movimiento,
        updated: EditTransferMovementValues,
        in context: ModelContext
    ) throws {
        let keys = affectedTransferKeys(salida: salida, entrada: entrada, updated: updated)
        for key in keys {
            try validateTransferProjectedBalance(
                key: key,
                salida: salida,
                entrada: entrada,
                updated: updated,
                in: context
            )
        }
    }

    private func affectedTransferKeys(
        salida: Movimiento,
        entrada: Movimiento,
        updated: EditTransferMovementValues
    ) -> Set<HoldingKey> {
        var keys: Set<HoldingKey> = []
        if let origin = salida.carteraOrigen, let crypto = salida.crypto {
            keys.insert(HoldingKey(carteraId: origin.id, cryptoId: crypto.id))
        }
        if let destination = entrada.carteraDestino, let crypto = entrada.crypto {
            keys.insert(HoldingKey(carteraId: destination.id, cryptoId: crypto.id))
        }
        keys.insert(HoldingKey(carteraId: updated.carteraOrigen.id, cryptoId: updated.crypto.id))
        keys.insert(HoldingKey(carteraId: updated.carteraDestino.id, cryptoId: updated.crypto.id))
        return keys
    }

    private func validateTransferProjectedBalance(
        key: HoldingKey,
        salida: Movimiento,
        entrada: Movimiento,
        updated: EditTransferMovementValues,
        in context: ModelContext
    ) throws {
        guard let portfolio = portfolio(for: key, in: context),
              let cartera = try fetchCartera(id: key.carteraId, in: context),
              let crypto = try fetchCrypto(id: key.cryptoId, in: context) else {
            // Legacy wallets without a portfolio cannot own a materialized holding row.
            return
        }

        let holdingKey = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        let current = try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == holdingKey })
        ).first?.cantidad ?? 0

        var delta: Decimal = 0

        // Revert old salida.
        if salida.carteraOrigen?.id == key.carteraId && salida.crypto?.id == key.cryptoId {
            delta += salida.cantidadCryptoSalida
        }
        // Revert old entrada.
        if entrada.carteraDestino?.id == key.carteraId && entrada.crypto?.id == key.cryptoId {
            delta -= entrada.cantidadCryptoEntrada
        }
        // Apply new salida.
        if updated.carteraOrigen.id == key.carteraId && updated.crypto.id == key.cryptoId {
            delta -= updated.cantidadCryptoSalida
        }
        // Apply new entrada.
        if updated.carteraDestino.id == key.carteraId && updated.crypto.id == key.cryptoId {
            delta += updated.cantidadCryptoEntrada
        }

        guard current + delta >= 0 else {
            throw EditMovementError.insufficientHoldings
        }
    }

    // MARK: - Swap validation

    /// Projects the balance for every affected `(portfolio, cartera, crypto)` key
    /// after reverting the old swap pair and applying the new one. Fails fast if any
    /// key would go negative.
    private func validateSwapEdit(
        salida: Movimiento,
        entrada: Movimiento,
        updated: EditSwapMovementValues,
        in context: ModelContext
    ) throws {
        let keys = affectedSwapKeys(salida: salida, entrada: entrada, updated: updated)
        for key in keys {
            try validateSwapProjectedBalance(
                key: key,
                salida: salida,
                entrada: entrada,
                updated: updated,
                in: context
            )
        }
    }

    private func affectedSwapKeys(
        salida: Movimiento,
        entrada: Movimiento,
        updated: EditSwapMovementValues
    ) -> Set<HoldingKey> {
        var keys: Set<HoldingKey> = []
        if let cartera = salida.cartera, let crypto = salida.cryptoOrigen {
            keys.insert(HoldingKey(carteraId: cartera.id, cryptoId: crypto.id))
        }
        if let cartera = entrada.cartera, let crypto = entrada.cryptoDestino {
            keys.insert(HoldingKey(carteraId: cartera.id, cryptoId: crypto.id))
        }
        keys.insert(HoldingKey(carteraId: updated.cartera.id, cryptoId: updated.cryptoOrigen.id))
        keys.insert(HoldingKey(carteraId: updated.cartera.id, cryptoId: updated.cryptoDestino.id))
        return keys
    }

    private func validateSwapProjectedBalance(
        key: HoldingKey,
        salida: Movimiento,
        entrada: Movimiento,
        updated: EditSwapMovementValues,
        in context: ModelContext
    ) throws {
        guard let portfolio = portfolio(for: key, in: context),
              let cartera = try fetchCartera(id: key.carteraId, in: context),
              let crypto = try fetchCrypto(id: key.cryptoId, in: context) else {
            return
        }

        let holdingKey = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        let current = try context.fetch(
            FetchDescriptor<Holding>(predicate: #Predicate { $0.id == holdingKey })
        ).first?.cantidad ?? 0

        var delta: Decimal = 0

        // Revert old swapSalida: it subtracted the origin crypto.
        if salida.cartera?.id == key.carteraId && salida.cryptoOrigen?.id == key.cryptoId {
            delta += salida.cantidadOrigen
        }
        // Revert old swapEntrada: it added the destination crypto.
        if entrada.cartera?.id == key.carteraId && entrada.cryptoDestino?.id == key.cryptoId {
            delta -= entrada.cantidadDestino
        }
        // Apply new swapSalida: subtract the origin crypto.
        if updated.cartera.id == key.carteraId && updated.cryptoOrigen.id == key.cryptoId {
            delta -= updated.cantidadOrigen
        }
        // Apply new swapEntrada: add the destination crypto.
        if updated.cartera.id == key.carteraId && updated.cryptoDestino.id == key.cryptoId {
            delta += updated.cantidadDestino
        }

        guard current + delta >= 0 else {
            throw EditMovementError.insufficientHoldings
        }
    }

    private func portfolio(for key: HoldingKey, in context: ModelContext) -> Portfolio? {
        guard let cartera = try? fetchCartera(id: key.carteraId, in: context),
              let portfolio = cartera.portfolio ?? PortfolioQueries.defaultPortfolio(in: context) else {
            return nil
        }
        return portfolio
    }

    // MARK: - Lookups

    private func fetchCartera(id: UUID?, in context: ModelContext) throws -> Cartera? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Cartera>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchCrypto(id: UUID?, in context: ModelContext) throws -> Crypto? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Crypto>(predicate: #Predicate { $0.id == id })).first
    }

    private func pairedTransferEntrada(for salida: Movimiento, in context: ModelContext) throws -> Movimiento? {
        guard let groupId = salida.groupId else { return nil }
        return try context.fetch(
            FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.groupId == groupId && $0.tipoRaw == "transferenciaEntrada" }
            )
        ).first
    }

    private func pairedSwapEntrada(for salida: Movimiento, in context: ModelContext) throws -> Movimiento? {
        guard let groupId = salida.groupId else { return nil }
        return try context.fetch(
            FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.groupId == groupId && $0.tipoRaw == "swapEntrada" }
            )
        ).first
    }

    private struct HoldingKey: Hashable {
        let carteraId: UUID
        let cryptoId: UUID
    }
}

