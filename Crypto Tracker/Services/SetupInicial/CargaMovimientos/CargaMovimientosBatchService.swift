import Foundation
import SwiftData

struct CargaMovimientosFileSelection {
    let entrada: URL?
    let salida: URL?
    let entreCarteras: URL?
    let swap: URL?
}

enum CargaMovimientosBatchError: LocalizedError, Equatable {
    case incompleteExistingPair
    case negativeBalance

    var errorDescription: String? {
        switch self {
        case .incompleteExistingPair:
            return "An existing transfer or swap is incomplete. Restore or remove the partial operation before importing it again."
        case .negativeBalance:
            return "The movement history would produce a negative crypto balance. Verify that every outgoing movement has sufficient prior funds."
        }
    }
}

@MainActor
struct CargaMovimientosBatchService {
    typealias WorksheetReader = (URL) async throws -> ExcelWorksheet

    private let modelContext: ModelContext
    private let holdingService: HoldingServiceProtocol
    private let readWorksheet: WorksheetReader
    private let progress: (String) -> Void

    init(
        modelContext: ModelContext,
        holdingService: HoldingServiceProtocol = HoldingService(),
        readWorksheet: @escaping WorksheetReader = ExcelReader.read,
        progress: @escaping (String) -> Void = { _ in }
    ) {
        self.modelContext = modelContext
        self.holdingService = holdingService
        self.readWorksheet = readWorksheet
        self.progress = progress
    }

    func cargar(
        archivos: CargaMovimientosFileSelection,
        cryptos: [Crypto],
        carteras: [Cartera],
        fiats: [FIAT]
    ) async throws -> [String: Int] {
        let existentes = try modelContext.fetch(FetchDescriptor<Movimiento>())
        let grupos: [(String, [Movimiento])]
        do {
            grupos = try await parsearTodos(
                archivos: archivos,
                cryptos: cryptos,
                carteras: carteras,
                fiats: fiats
            )
        } catch {
            modelContext.rollback()
            throw error
        }
        var disponiblesPorHuella = Dictionary(
            grouping: existentes.filter { !$0.tipo.isPairedImportMovement },
            by: MovimientoImportFingerprint.init
        )
            .mapValues(\.count)
        let existingPairedMovements = existentes.filter { $0.tipo.isPairedImportMovement }
        var availablePairLegs = Dictionary(
            grouping: existingPairedMovements,
            by: MovimientoImportFingerprint.init
        ).mapValues(\.count)
        var availableCompletePairs: [MovimientoImportPairFingerprint: Int] = [:]

        let existingPairsByGroup = Dictionary(grouping: existingPairedMovements) { $0.groupId }
        for (groupId, movements) in existingPairsByGroup where groupId != nil {
            if let pairFingerprint = MovimientoImportPairFingerprint(movements) {
                availableCompletePairs[pairFingerprint, default: 0] += 1
            }
        }
        var nuevosPorGrupo: [(String, [Movimiento])] = []

        for (nombre, movimientos) in grupos {
            var nuevos: [Movimiento] = []
            var processedPairIDs = Set<UUID>()
            for movimiento in movimientos {
                if movimiento.tipo.isPairedImportMovement {
                    guard let groupId = movimiento.groupId else {
                        modelContext.rollback()
                        throw CargaMovimientosBatchError.incompleteExistingPair
                    }
                    guard processedPairIDs.insert(groupId).inserted else {
                        continue
                    }
                    let pair = movimientos.filter { $0.groupId == groupId }
                    guard let pairFingerprint = MovimientoImportPairFingerprint(pair) else {
                        modelContext.rollback()
                        throw CargaMovimientosBatchError.incompleteExistingPair
                    }

                    if let available = availableCompletePairs[pairFingerprint], available > 0 {
                        availableCompletePairs[pairFingerprint] = available - 1
                        for leg in pair {
                            let fingerprint = MovimientoImportFingerprint(leg)
                            availablePairLegs[fingerprint, default: 0] -= 1
                            modelContext.delete(leg)
                        }
                    } else if pair.contains(where: {
                        availablePairLegs[MovimientoImportFingerprint($0), default: 0] > 0
                    }) {
                        modelContext.rollback()
                        throw CargaMovimientosBatchError.incompleteExistingPair
                    } else {
                        nuevos.append(contentsOf: pair)
                    }
                    continue
                }

                let huella = MovimientoImportFingerprint(movimiento)
                if let disponibles = disponiblesPorHuella[huella], disponibles > 0 {
                    disponiblesPorHuella[huella] = disponibles - 1
                    modelContext.delete(movimiento)
                } else {
                    nuevos.append(movimiento)
                }
            }
            nuevosPorGrupo.append((nombre, nuevos))
        }

        guard nuevosPorGrupo.contains(where: { !$0.1.isEmpty }) else {
            progress("No se encontraron movimientos nuevos; la carga ya estaba aplicada")
            return Dictionary(uniqueKeysWithValues: nuevosPorGrupo.map { ($0.0, 0) })
        }

        do {
            for (_, movimientos) in nuevosPorGrupo {
                movimientos.forEach(modelContext.insert)
            }
            try reconstruirHoldings()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        return Dictionary(uniqueKeysWithValues: nuevosPorGrupo.map { ($0.0, $0.1.count) })
    }

    private func parsearTodos(
        archivos: CargaMovimientosFileSelection,
        cryptos: [Crypto],
        carteras: [Cartera],
        fiats: [FIAT]
    ) async throws -> [(String, [Movimiento])] {
        var grupos: [(String, [Movimiento])] = []

        if let url = archivos.entrada {
            progress("Validando Movimientos de Entrada...")
            let worksheet = try await readWorksheet(url)
            grupos.append(("Movimientos de Entrada", try MovimientoEntradaParser.parse(
                worksheet: worksheet, carteras: carteras, cryptos: cryptos, fiats: fiats
            )))
        }
        if let url = archivos.salida {
            progress("Validando Movimientos de Salida...")
            let worksheet = try await readWorksheet(url)
            grupos.append(("Movimientos de Salida", try MovimientoSalidaParser.parse(
                worksheet: worksheet, carteras: carteras, cryptos: cryptos, fiats: fiats, skipFundCheck: true
            )))
        }
        if let url = archivos.entreCarteras {
            progress("Validando Movimientos Entre Carteras...")
            let worksheet = try await readWorksheet(url)
            grupos.append(("Movimientos Entre Carteras", try MovimientoEntreCarterasParser.parse(
                worksheet: worksheet, carteras: carteras, cryptos: cryptos, skipFundCheck: true
            )))
        }
        if let url = archivos.swap {
            progress("Validando Movimientos Swap...")
            let worksheet = try await readWorksheet(url)
            grupos.append(("Movimientos Swap", try MovimientoSwapParser.parse(
                worksheet: worksheet, carteras: carteras, cryptos: cryptos, skipFundCheck: true
            )))
        }
        return grupos
    }

    private func reconstruirHoldings() throws {
        progress("Reconstruyendo balances (Holdings)...")
        try modelContext.fetch(FetchDescriptor<Holding>()).forEach(modelContext.delete)
        let movimientos = try modelContext.fetch(
            FetchDescriptor<Movimiento>(sortBy: [SortDescriptor(\.fecha, order: .forward)])
        )
        var replayBalances: [String: Decimal] = [:]
        for movimiento in movimientos {
            try validateReplayBalance(for: movimiento, balances: &replayBalances)
            try holdingService.updateHoldingForMovement(movimiento, in: modelContext)
        }
        progress("Balances reconstruidos para \(movimientos.count) movimientos")
    }

    private func validateReplayBalance(
        for movement: Movimiento,
        balances: inout [String: Decimal]
    ) throws {
        switch movement.tipo {
        case .entrada:
            try applyReplayDelta(
                movement.cantidadCrypto,
                wallet: movement.cartera,
                crypto: movement.crypto,
                balances: &balances
            )
        case .salida:
            try applyReplayDelta(
                -movement.cantidadCrypto,
                wallet: movement.cartera,
                crypto: movement.crypto,
                balances: &balances
            )
        case .transferenciaSalida:
            try applyReplayDelta(
                -movement.cantidadCryptoSalida,
                wallet: movement.carteraOrigen,
                crypto: movement.crypto,
                balances: &balances
            )
        case .transferenciaEntrada:
            try applyReplayDelta(
                movement.cantidadCryptoEntrada,
                wallet: movement.carteraDestino,
                crypto: movement.crypto,
                balances: &balances
            )
        case .swapSalida:
            try applyReplayDelta(
                -movement.cantidadOrigen,
                wallet: movement.cartera,
                crypto: movement.cryptoOrigen,
                balances: &balances
            )
        case .swapEntrada:
            try applyReplayDelta(
                movement.cantidadDestino,
                wallet: movement.cartera,
                crypto: movement.cryptoDestino,
                balances: &balances
            )
        case .ajuste:
            guard let key = replayKey(wallet: movement.cartera, crypto: movement.crypto) else { return }
            balances[key] = max(movement.cantidadCrypto, 0)
        case .comision:
            break
        }
    }

    private func applyReplayDelta(
        _ delta: Decimal,
        wallet: Cartera?,
        crypto: Crypto?,
        balances: inout [String: Decimal]
    ) throws {
        guard let key = replayKey(wallet: wallet, crypto: crypto) else { return }
        let newBalance = balances[key, default: 0] + delta
        guard newBalance >= 0 else {
            throw CargaMovimientosBatchError.negativeBalance
        }
        balances[key] = newBalance
    }

    private func replayKey(wallet: Cartera?, crypto: Crypto?) -> String? {
        guard let wallet, let crypto,
              let portfolio = wallet.portfolio ?? PortfolioQueries.defaultPortfolio(in: modelContext) else {
            return nil
        }
        return Holding.makeId(portfolio: portfolio, cartera: wallet, crypto: crypto)
    }
}

private extension TipoMovimiento {
    var isPairedImportMovement: Bool {
        switch self {
        case .transferenciaEntrada, .transferenciaSalida, .swapEntrada, .swapSalida:
            return true
        default:
            return false
        }
    }
}

private struct MovimientoImportPairFingerprint: Hashable {
    private let outgoing: MovimientoImportFingerprint
    private let incoming: MovimientoImportFingerprint

    init?(_ movements: [Movimiento]) {
        guard movements.count == 2 else { return nil }

        if let outgoing = movements.first(where: { $0.tipo == .transferenciaSalida }),
           let incoming = movements.first(where: { $0.tipo == .transferenciaEntrada }) {
            self.outgoing = MovimientoImportFingerprint(outgoing)
            self.incoming = MovimientoImportFingerprint(incoming)
            return
        }

        if let outgoing = movements.first(where: { $0.tipo == .swapSalida }),
           let incoming = movements.first(where: { $0.tipo == .swapEntrada }) {
            self.outgoing = MovimientoImportFingerprint(outgoing)
            self.incoming = MovimientoImportFingerprint(incoming)
            return
        }

        return nil
    }
}

private struct MovimientoImportFingerprint: Hashable {
    private let values: [String]

    init(_ movimiento: Movimiento) {
        values = [
            movimiento.tipoRaw,
            String(movimiento.fecha.timeIntervalSinceReferenceDate),
            NSDecimalNumber(decimal: movimiento.cantidadCrypto).stringValue,
            NSDecimalNumber(decimal: movimiento.precioUSD).stringValue,
            NSDecimalNumber(decimal: movimiento.valorTotalUSD).stringValue,
            String(movimiento.usaFiatAlterno),
            Self.decimal(movimiento.precioFiatAlterno),
            Self.decimal(movimiento.valorTotalFiatAlterno),
            NSDecimalNumber(decimal: movimiento.cantidadCryptoSalida).stringValue,
            NSDecimalNumber(decimal: movimiento.cantidadCryptoEntrada).stringValue,
            NSDecimalNumber(decimal: movimiento.cantidadCryptoComision).stringValue,
            NSDecimalNumber(decimal: movimiento.cantidadOrigen).stringValue,
            NSDecimalNumber(decimal: movimiento.cantidadDestino).stringValue,
            NSDecimalNumber(decimal: movimiento.precioUSDOrigen).stringValue,
            NSDecimalNumber(decimal: movimiento.precioUSDDestino).stringValue,
            movimiento.cartera?.id.uuidString ?? "",
            movimiento.crypto?.id.uuidString ?? "",
            movimiento.fiatAlterno?.id.uuidString ?? "",
            movimiento.carteraOrigen?.id.uuidString ?? "",
            movimiento.carteraDestino?.id.uuidString ?? "",
            movimiento.cryptoOrigen?.id.uuidString ?? "",
            movimiento.cryptoDestino?.id.uuidString ?? ""
        ]
    }

    private static func decimal(_ value: Decimal?) -> String {
        value.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
    }
}
