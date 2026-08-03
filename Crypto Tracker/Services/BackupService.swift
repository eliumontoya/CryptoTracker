import Foundation
import SwiftData

// MARK: - Protocol

protocol BackupService: AnyObject {
    func export(in context: ModelContext) throws -> Data
    func restore(from data: Data, in context: ModelContext) throws
}

// MARK: - Backup Container

private struct BackupContainer: Codable {
    let version: Int
    let exportedAt: Date
    let portfolios: [BackupPortfolio]
    let cryptos: [BackupCrypto]
    let fiats: [BackupFIAT]
    let carteras: [BackupCartera]
    let holdings: [BackupHolding]
    let movimientos: [BackupMovimiento]
    let preciosHistoricos: [BackupPrecioHistorico]
    let snapshots: [BackupPortfolioSnapshot]
    let syncConfigs: [BackupCryptoSyncConfig]
}

private struct BackupPortfolio: Codable {
    let id: UUID
    let nombre: String
    let descripcion: String
    let isDefault: Bool
}

private struct BackupCrypto: Codable {
    let id: UUID
    let nombre: String
    let simbolo: String
    let coingeckoId: String?
    let precio: Decimal
    let ultimaActualizacion: Date
}

private struct BackupFIAT: Codable {
    let id: UUID
    let nombre: String
    let simbolo: String
    let precioUSD: Decimal
}

private struct BackupCartera: Codable {
    let id: UUID
    let nombre: String
    let simbolo: String
    let isMain: Bool
    let portfolioId: UUID?
}

private struct BackupHolding: Codable {
    let id: String
    let portfolioId: UUID
    let carteraId: UUID
    let cryptoId: UUID
    let cantidad: Decimal
    let updatedAt: Date
}

private struct BackupMovimiento: Codable {
    let id: UUID
    let fecha: Date
    let tipoRaw: String
    let groupId: UUID?
    let cantidadCrypto: Decimal
    let precioUSD: Decimal
    let valorTotalUSD: Decimal
    let usaFiatAlterno: Bool
    let precioFiatAlterno: Decimal?
    let valorTotalFiatAlterno: Decimal?
    let cantidadCryptoSalida: Decimal
    let cantidadCryptoEntrada: Decimal
    let cantidadCryptoComision: Decimal
    let cantidadOrigen: Decimal
    let cantidadDestino: Decimal
    let precioUSDOrigen: Decimal
    let precioUSDDestino: Decimal
    let carteraId: UUID?
    let cryptoId: UUID?
    let fiatAlternoId: UUID?
    let carteraOrigenId: UUID?
    let carteraDestinoId: UUID?
    let cryptoOrigenId: UUID?
    let cryptoDestinoId: UUID?
}

private struct BackupPrecioHistorico: Codable {
    let id: UUID
    let fecha: Date
    let precio: Decimal
    let cryptoId: UUID
}

private struct BackupPortfolioSnapshot: Codable {
    let id: UUID
    let date: Date
    let totalUSD: Decimal
    let portfolioId: UUID
}

private struct BackupCryptoSyncConfig: Codable {
    let id: UUID
    let cryptoId: UUID
    let syncUrl: String
    let defaultPrice: Decimal
}

// MARK: - JSON Implementation

final class JSONBackupService: BackupService {
    private let backupVersion = 1

    func export(in context: ModelContext) throws -> Data {
        let portfolios = (try? context.fetch(FetchDescriptor<Portfolio>())) ?? []
        let cryptos = (try? context.fetch(FetchDescriptor<Crypto>())) ?? []
        let fiats = (try? context.fetch(FetchDescriptor<FIAT>())) ?? []
        let carteras = (try? context.fetch(FetchDescriptor<Cartera>())) ?? []
        let holdings = (try? context.fetch(FetchDescriptor<Holding>())) ?? []
        let movimientos = (try? context.fetch(FetchDescriptor<Movimiento>())) ?? []
        let preciosHistoricos = (try? context.fetch(FetchDescriptor<PrecioHistorico>())) ?? []
        let snapshots = (try? context.fetch(FetchDescriptor<PortfolioSnapshot>())) ?? []
        let syncConfigs = (try? context.fetch(FetchDescriptor<CryptoSyncConfig>())) ?? []

        let container = BackupContainer(
            version: backupVersion,
            exportedAt: Date(),
            portfolios: portfolios.map(mapPortfolio),
            cryptos: cryptos.map(mapCrypto),
            fiats: fiats.map(mapFIAT),
            carteras: carteras.map(mapCartera),
            holdings: holdings.map(mapHolding),
            movimientos: movimientos.map(mapMovimiento),
            preciosHistoricos: preciosHistoricos.map(mapPrecioHistorico),
            snapshots: snapshots.map(mapSnapshot),
            syncConfigs: syncConfigs.map(mapSyncConfig)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(container)
    }

    func restore(from data: Data, in context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let container = try decoder.decode(BackupContainer.self, from: data)

        guard container.version == backupVersion else {
            throw BackupError.unsupportedVersion
        }

        try clearAllData(in: context)

        let portfolios = container.portfolios.map { portfolioDTO -> Portfolio in
            let portfolio = Portfolio(
                nombre: portfolioDTO.nombre,
                descripcion: portfolioDTO.descripcion,
                isDefault: portfolioDTO.isDefault
            )
            portfolio.id = portfolioDTO.id
            context.insert(portfolio)
            return portfolio
        }
        let portfolioById = Dictionary(uniqueKeysWithValues: portfolios.map { ($0.id, $0) })

        let cryptos = container.cryptos.map { cryptoDTO -> Crypto in
            let crypto = Crypto(
                nombre: cryptoDTO.nombre,
                simbolo: cryptoDTO.simbolo,
                precio: cryptoDTO.precio,
                coingeckoId: cryptoDTO.coingeckoId
            )
            crypto.id = cryptoDTO.id
            crypto.ultimaActualizacion = cryptoDTO.ultimaActualizacion
            context.insert(crypto)
            return crypto
        }
        let cryptoById = Dictionary(uniqueKeysWithValues: cryptos.map { ($0.id, $0) })

        let fiats = container.fiats.map { fiatDTO -> FIAT in
            let fiat = FIAT(nombre: fiatDTO.nombre, simbolo: fiatDTO.simbolo, precioUSD: fiatDTO.precioUSD)
            fiat.id = fiatDTO.id
            context.insert(fiat)
            return fiat
        }
        let fiatById = Dictionary(uniqueKeysWithValues: fiats.map { ($0.id, $0) })

        let carteras = container.carteras.map { carteraDTO -> Cartera in
            let cartera = Cartera(
                nombre: carteraDTO.nombre,
                simbolo: carteraDTO.simbolo,
                isMain: carteraDTO.isMain,
                portfolio: portfolioById[carteraDTO.portfolioId ?? UUID()]
            )
            cartera.id = carteraDTO.id
            context.insert(cartera)
            return cartera
        }
        let carteraById = Dictionary(uniqueKeysWithValues: carteras.map { ($0.id, $0) })

        for holdingDTO in container.holdings {
            guard let portfolio = portfolioById[holdingDTO.portfolioId],
                  let cartera = carteraById[holdingDTO.carteraId],
                  let crypto = cryptoById[holdingDTO.cryptoId] else { continue }

            let holding = Holding(portfolio: portfolio, cartera: cartera, crypto: crypto, cantidad: holdingDTO.cantidad)
            holding.id = holdingDTO.id
            holding.updatedAt = holdingDTO.updatedAt
            context.insert(holding)
        }

        for movimientoDTO in container.movimientos {
            let movimiento = Movimiento(tipo: .ajuste)
            movimiento.id = movimientoDTO.id
            movimiento.fecha = movimientoDTO.fecha
            movimiento.tipoRaw = movimientoDTO.tipoRaw
            movimiento.groupId = movimientoDTO.groupId
            movimiento.cantidadCrypto = movimientoDTO.cantidadCrypto
            movimiento.precioUSD = movimientoDTO.precioUSD
            movimiento.valorTotalUSD = movimientoDTO.valorTotalUSD
            movimiento.usaFiatAlterno = movimientoDTO.usaFiatAlterno
            movimiento.precioFiatAlterno = movimientoDTO.precioFiatAlterno
            movimiento.valorTotalFiatAlterno = movimientoDTO.valorTotalFiatAlterno
            movimiento.cantidadCryptoSalida = movimientoDTO.cantidadCryptoSalida
            movimiento.cantidadCryptoEntrada = movimientoDTO.cantidadCryptoEntrada
            movimiento.cantidadCryptoComision = movimientoDTO.cantidadCryptoComision
            movimiento.cantidadOrigen = movimientoDTO.cantidadOrigen
            movimiento.cantidadDestino = movimientoDTO.cantidadDestino
            movimiento.precioUSDOrigen = movimientoDTO.precioUSDOrigen
            movimiento.precioUSDDestino = movimientoDTO.precioUSDDestino
            movimiento.cartera = carteraById[movimientoDTO.carteraId ?? UUID()]
            movimiento.crypto = cryptoById[movimientoDTO.cryptoId ?? UUID()]
            movimiento.fiatAlterno = fiatById[movimientoDTO.fiatAlternoId ?? UUID()]
            movimiento.carteraOrigen = carteraById[movimientoDTO.carteraOrigenId ?? UUID()]
            movimiento.carteraDestino = carteraById[movimientoDTO.carteraDestinoId ?? UUID()]
            movimiento.cryptoOrigen = cryptoById[movimientoDTO.cryptoOrigenId ?? UUID()]
            movimiento.cryptoDestino = cryptoById[movimientoDTO.cryptoDestinoId ?? UUID()]
            context.insert(movimiento)
        }

        for precioDTO in container.preciosHistoricos {
            guard let crypto = cryptoById[precioDTO.cryptoId] else { continue }
            let precio = PrecioHistorico(crypto: crypto, precio: precioDTO.precio, fecha: precioDTO.fecha)
            precio.id = precioDTO.id
            context.insert(precio)
        }

        for snapshotDTO in container.snapshots {
            let snapshot = PortfolioSnapshot(
                date: snapshotDTO.date,
                totalUSD: snapshotDTO.totalUSD,
                portfolioId: snapshotDTO.portfolioId
            )
            snapshot.id = snapshotDTO.id
            context.insert(snapshot)
        }

        for syncDTO in container.syncConfigs {
            guard let crypto = cryptoById[syncDTO.cryptoId] else { continue }
            let config = CryptoSyncConfig(crypto: crypto, syncUrl: syncDTO.syncUrl, defaultPrice: syncDTO.defaultPrice)
            config.id = syncDTO.id
            context.insert(config)
        }

        try context.save()
    }

    private func clearAllData(in context: ModelContext) throws {
        let entities: [any PersistentModel.Type] = [
            PortfolioSnapshot.self,
            PrecioHistorico.self,
            Movimiento.self,
            Holding.self,
            CryptoSyncConfig.self,
            Cartera.self,
            Crypto.self,
            FIAT.self,
            Portfolio.self
        ]

        for entity in entities {
            switch entity {
            case is PortfolioSnapshot.Type:
                try context.fetch(FetchDescriptor<PortfolioSnapshot>()).forEach(context.delete)
            case is PrecioHistorico.Type:
                try context.fetch(FetchDescriptor<PrecioHistorico>()).forEach(context.delete)
            case is Movimiento.Type:
                try context.fetch(FetchDescriptor<Movimiento>()).forEach(context.delete)
            case is Holding.Type:
                try context.fetch(FetchDescriptor<Holding>()).forEach(context.delete)
            case is CryptoSyncConfig.Type:
                try context.fetch(FetchDescriptor<CryptoSyncConfig>()).forEach(context.delete)
            case is Cartera.Type:
                try context.fetch(FetchDescriptor<Cartera>()).forEach(context.delete)
            case is Crypto.Type:
                try context.fetch(FetchDescriptor<Crypto>()).forEach(context.delete)
            case is FIAT.Type:
                try context.fetch(FetchDescriptor<FIAT>()).forEach(context.delete)
            case is Portfolio.Type:
                try context.fetch(FetchDescriptor<Portfolio>()).forEach(context.delete)
            default:
                break
            }
        }
    }

    // MARK: - Mapping

    private func mapPortfolio(_ portfolio: Portfolio) -> BackupPortfolio {
        BackupPortfolio(
            id: portfolio.id,
            nombre: portfolio.nombre,
            descripcion: portfolio.descripcion,
            isDefault: portfolio.isDefault
        )
    }

    private func mapCrypto(_ crypto: Crypto) -> BackupCrypto {
        BackupCrypto(
            id: crypto.id,
            nombre: crypto.nombre,
            simbolo: crypto.simbolo,
            coingeckoId: crypto.coingeckoId,
            precio: crypto.precio,
            ultimaActualizacion: crypto.ultimaActualizacion
        )
    }

    private func mapFIAT(_ fiat: FIAT) -> BackupFIAT {
        BackupFIAT(
            id: fiat.id,
            nombre: fiat.nombre,
            simbolo: fiat.simbolo,
            precioUSD: fiat.precioUSD
        )
    }

    private func mapCartera(_ cartera: Cartera) -> BackupCartera {
        BackupCartera(
            id: cartera.id,
            nombre: cartera.nombre,
            simbolo: cartera.simbolo,
            isMain: cartera.isMain,
            portfolioId: cartera.portfolio?.id
        )
    }

    private func mapHolding(_ holding: Holding) -> BackupHolding {
        BackupHolding(
            id: holding.id,
            portfolioId: holding.portfolio.id,
            carteraId: holding.cartera.id,
            cryptoId: holding.crypto.id,
            cantidad: holding.cantidad,
            updatedAt: holding.updatedAt
        )
    }

    private func mapMovimiento(_ movimiento: Movimiento) -> BackupMovimiento {
        BackupMovimiento(
            id: movimiento.id,
            fecha: movimiento.fecha,
            tipoRaw: movimiento.tipoRaw,
            groupId: movimiento.groupId,
            cantidadCrypto: movimiento.cantidadCrypto,
            precioUSD: movimiento.precioUSD,
            valorTotalUSD: movimiento.valorTotalUSD,
            usaFiatAlterno: movimiento.usaFiatAlterno,
            precioFiatAlterno: movimiento.precioFiatAlterno,
            valorTotalFiatAlterno: movimiento.valorTotalFiatAlterno,
            cantidadCryptoSalida: movimiento.cantidadCryptoSalida,
            cantidadCryptoEntrada: movimiento.cantidadCryptoEntrada,
            cantidadCryptoComision: movimiento.cantidadCryptoComision,
            cantidadOrigen: movimiento.cantidadOrigen,
            cantidadDestino: movimiento.cantidadDestino,
            precioUSDOrigen: movimiento.precioUSDOrigen,
            precioUSDDestino: movimiento.precioUSDDestino,
            carteraId: movimiento.cartera?.id,
            cryptoId: movimiento.crypto?.id,
            fiatAlternoId: movimiento.fiatAlterno?.id,
            carteraOrigenId: movimiento.carteraOrigen?.id,
            carteraDestinoId: movimiento.carteraDestino?.id,
            cryptoOrigenId: movimiento.cryptoOrigen?.id,
            cryptoDestinoId: movimiento.cryptoDestino?.id
        )
    }

    private func mapPrecioHistorico(_ precio: PrecioHistorico) -> BackupPrecioHistorico {
        BackupPrecioHistorico(
            id: precio.id,
            fecha: precio.fecha,
            precio: precio.precio,
            cryptoId: precio.crypto?.id ?? UUID()
        )
    }

    private func mapSnapshot(_ snapshot: PortfolioSnapshot) -> BackupPortfolioSnapshot {
        BackupPortfolioSnapshot(
            id: snapshot.id,
            date: snapshot.date,
            totalUSD: snapshot.totalUSD,
            portfolioId: snapshot.portfolioId
        )
    }

    private func mapSyncConfig(_ config: CryptoSyncConfig) -> BackupCryptoSyncConfig {
        BackupCryptoSyncConfig(
            id: config.id,
            cryptoId: config.crypto?.id ?? UUID(),
            syncUrl: config.syncUrl,
            defaultPrice: config.defaultPrice
        )
    }
}

// MARK: - Errors

enum BackupError: Error {
    case unsupportedVersion
}
