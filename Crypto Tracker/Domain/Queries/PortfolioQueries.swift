import Foundation
import SwiftData

// MARK: - Read Models (CQRS-lite)

/// Resumen agregado de un portfolio en USD.
struct PortfolioSummary {
    let portfolioId: UUID
    var invertidoUSD: Decimal
    var valorActualUSD: Decimal
    var totalVentasUSD: Decimal
    var gananciaUSD: Decimal
    var rendimientoPct: Decimal
}

/// Agregado por crypto dentro de un portfolio.
struct CryptoAggregate: Identifiable {
    var id: UUID { crypto.id }
    let crypto: Crypto
    var qty: Decimal
    var adquiridoUSD: Decimal
    var ventasUSD: Decimal
    var valorActualUSD: Decimal
    var pnlUSD: Decimal
    var pnlPct: Decimal

    var simbolo: String { crypto.simbolo }
    var avgCostUSD: Decimal { qty > 0 ? adquiridoUSD / qty : 0 }
}

/// Renglón de una crypto dentro de una cartera.
struct WalletHoldingRow: Identifiable {
    var id: UUID { cryptoId }
    let crypto: Crypto
    var cryptoId: UUID { crypto.id }
    var simbolo: String { crypto.simbolo }
    var cantidad: Decimal
    var precioUSD: Decimal
    var valorUSD: Decimal
    var invertidoUSD: Decimal
    var gananciaUSD: Decimal
    var pnlPct: Decimal
}

/// Holdings materializados de una cartera.
struct WalletHoldings: Identifiable {
    var id: UUID { walletId }
    let walletId: UUID
    var walletName: String
    var holdings: [WalletHoldingRow]
    var valorTotalUSD: Decimal
    var totalInvertidoUSD: Decimal
    var gananciaUSD: Decimal
    var rendimientoPct: Decimal
}

// MARK: - Queries de lectura (CQRS-lite)

/// Capa de lectura del dominio. El balance por crypto proviene de la tabla
/// materializada `Holding` (evita sumar N movimientos por cada cálculo); el
/// costo acumulado se agrega en una sola pasada sobre los movimientos.
enum PortfolioQueries {
    // MARK: - Portfolio

    /// Portfolio activo de la app: el marcado `isDefault` o, en su defecto, el primero.
    static func defaultPortfolio(in context: ModelContext) -> Portfolio? {
        let portfolios = (try? context.fetch(FetchDescriptor<Portfolio>())) ?? []
        return portfolios.first { $0.isDefault } ?? portfolios.first
    }

    static func portfolioSummary(portfolioId: UUID, in context: ModelContext) -> PortfolioSummary {
        let aggregates = portfolioByCryptos(portfolioId: portfolioId, in: context)

        let invertido = aggregates.reduce(Decimal(0)) { $0 + $1.adquiridoUSD }
        let ventas = aggregates.reduce(Decimal(0)) { $0 + $1.ventasUSD }
        let valor = aggregates.reduce(Decimal(0)) { $0 + $1.valorActualUSD }
        let ganancia = valor - invertido + ventas

        return PortfolioSummary(
            portfolioId: portfolioId,
            invertidoUSD: invertido,
            valorActualUSD: valor,
            totalVentasUSD: ventas,
            gananciaUSD: ganancia,
            rendimientoPct: invertido > 0 ? (ganancia / invertido) * 100 : 0
        )
    }

    static func portfolioByCryptos(portfolioId: UUID, in context: ModelContext) -> [CryptoAggregate] {
        let holdings = fetchHoldings(predicate: #Predicate { $0.portfolio.id == portfolioId }, in: context)

        // Qty materializada por crypto (fuente: tabla Holding).
        var qtyPorCrypto: [UUID: Decimal] = [:]
        var cryptoRef: [UUID: Crypto] = [:]
        for holding in holdings {
            qtyPorCrypto[holding.crypto.id, default: 0] += holding.cantidad
            cryptoRef[holding.crypto.id] = holding.crypto
        }

        let movimientos = movimientosDePortfolio(holdings: holdings, in: context)
        let costos = costoPorCrypto(movimientos: movimientos)

        return qtyPorCrypto.keys.compactMap { cryptoId -> CryptoAggregate? in
            guard let crypto = cryptoRef[cryptoId] else { return nil }
            let qty = qtyPorCrypto[cryptoId] ?? 0
            guard qty > 0 else { return nil }

            let adquirido = costos[cryptoId]?.adquiridoUSD ?? 0
            let ventas = costos[cryptoId]?.ventasUSD ?? 0
            let valor = qty * crypto.precio
            let ganancia = valor - adquirido + ventas

            return CryptoAggregate(
                crypto: crypto,
                qty: qty,
                adquiridoUSD: adquirido,
                ventasUSD: ventas,
                valorActualUSD: valor,
                pnlUSD: ganancia,
                pnlPct: adquirido > 0 ? (ganancia / adquirido) * 100 : 0
            )
        }
        .sorted { $0.valorActualUSD > $1.valorActualUSD }
    }

    // MARK: - Cartera

    static func carteras(portfolioId: UUID, in context: ModelContext) -> [Cartera] {
        (try? context.fetch(FetchDescriptor<Cartera>(
            predicate: #Predicate { $0.portfolio?.id == portfolioId },
            sortBy: [SortDescriptor(\.nombre)]
        ))) ?? []
    }

    static func holdingsByWallet(walletId: UUID, in context: ModelContext) -> WalletHoldings {
        let holdings = fetchHoldings(predicate: #Predicate { $0.cartera.id == walletId }, in: context)
        let movimientos = movementsByWallet(walletId: walletId, in: context)
        let costos = costoPorCrypto(movimientos: movimientos)

        let rows = holdings.map { holding -> WalletHoldingRow in
            let adquirido = costos[holding.crypto.id]?.adquiridoUSD ?? 0
            let ventas = costos[holding.crypto.id]?.ventasUSD ?? 0
            let valor = holding.cantidad * holding.crypto.precio
            let ganancia = valor - adquirido + ventas

            return WalletHoldingRow(
                crypto: holding.crypto,
                cantidad: holding.cantidad,
                precioUSD: holding.crypto.precio,
                valorUSD: valor,
                invertidoUSD: adquirido,
                gananciaUSD: ganancia,
                pnlPct: adquirido > 0 ? (ganancia / adquirido) * 100 : 0
            )
        }
        .sorted { $0.valorUSD > $1.valorUSD }

        let valorTotal = rows.reduce(Decimal(0)) { $0 + $1.valorUSD }
        let totalInvertido = rows.reduce(Decimal(0)) { $0 + $1.invertidoUSD }
        let gananciaTotal = rows.reduce(Decimal(0)) { $0 + $1.gananciaUSD }

        return WalletHoldings(
            walletId: walletId,
            walletName: holdings.first?.cartera.nombre ?? "Cartera",
            holdings: rows,
            valorTotalUSD: valorTotal,
            totalInvertidoUSD: totalInvertido,
            gananciaUSD: gananciaTotal,
            rendimientoPct: totalInvertido > 0 ? (gananciaTotal / totalInvertido) * 100 : 0
        )
    }

    static func movementsByWallet(walletId: UUID, assetId: UUID? = nil, in context: ModelContext) -> [Movimiento] {
        let descriptor: FetchDescriptor<Movimiento>
        if let assetId {
            descriptor = FetchDescriptor<Movimiento>(
                predicate: #Predicate {
                    $0.cartera?.id == walletId &&
                        ($0.crypto?.id == assetId || $0.cryptoOrigen?.id == assetId || $0.cryptoDestino?.id == assetId)
                },
                sortBy: [SortDescriptor(\.fecha, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Movimiento>(
                predicate: #Predicate { $0.cartera?.id == walletId },
                sortBy: [SortDescriptor(\.fecha, order: .reverse)]
            )
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Helpers

    private static func fetchHoldings(predicate: Predicate<Holding>, in context: ModelContext) -> [Holding] {
        (try? context.fetch(FetchDescriptor<Holding>(predicate: predicate))) ?? []
    }

    /// Movimientos de todas las carteras que aparecen en los holdings del portfolio.
    private static func movimientosDePortfolio(holdings: [Holding], in context: ModelContext) -> [Movimiento] {
        let walletIds = Set(holdings.map { $0.cartera.id })
        return walletIds.flatMap { movementsByWallet(walletId: $0, in: context) }
    }

    /// Costo acumulado por crypto: dinero invertido (entradas + swaps recibidos) y
    /// dinero recuperado (salidas + swaps enviados), todo en USD.
    private struct CryptoCost {
        var adquiridoUSD: Decimal = 0
        var ventasUSD: Decimal = 0
    }

    private static func costoPorCrypto(movimientos: [Movimiento]) -> [UUID: CryptoCost] {
        var costos: [UUID: CryptoCost] = [:]
        for movimiento in movimientos {
            switch movimiento.tipo {
            case .entrada:
                if let id = movimiento.crypto?.id {
                    costos[id, default: CryptoCost()].adquiridoUSD += movimiento.valorTotalUSD
                }
            case .salida:
                if let id = movimiento.crypto?.id {
                    costos[id, default: CryptoCost()].ventasUSD += movimiento.valorTotalUSD
                }
            case .swapEntrada:
                if let id = movimiento.cryptoDestino?.id {
                    costos[id, default: CryptoCost()].adquiridoUSD += movimiento.cantidadDestino * movimiento.precioUSDDestino
                }
            case .swapSalida:
                if let id = movimiento.cryptoOrigen?.id {
                    costos[id, default: CryptoCost()].ventasUSD += movimiento.cantidadOrigen * movimiento.precioUSDOrigen
                }
            case .transferenciaEntrada, .transferenciaSalida, .ajuste, .comision:
                // Las transferencias internas no cambian el capital del portfolio;
                // ajustes y comisiones no representan inversión ni venta.
                break
            }
        }
        return costos
    }
}
