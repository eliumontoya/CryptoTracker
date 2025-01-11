import Foundation

class MainPortfolioCalculator {
    static func calcularResumen(portfolioDetails: [CarteraDetail], carteras: [Cartera]) -> MainPortfolioSummary {
        let totalInvertidoUSD = portfolioDetails.reduce(0) { $0 + $1.totalInvertidoFIAT }
        let valorActualUSD = portfolioDetails.reduce(0) { $0 + $1.valorTotalUSD }
        
        // Calcular total de ventas incluyendo swaps
        let totalVentasUSD = carteras.reduce(Decimal(0)) { carteraSum, cartera in
            let ventasDirectas = cartera.movimientosEgreso.reduce(Decimal(0)) { movSum, movimiento in
                movSum + movimiento.valorTotalUSD
            }
            
            let ventasSwaps = cartera.swaps.reduce(Decimal(0)) { swapSum, movimiento in
                swapSum + (movimiento.cantidadOrigen * movimiento.precioUSDOrigen)
            }
            
            return carteraSum + ventasDirectas + ventasSwaps
        }
        
        let gananciaTotal = valorActualUSD - totalInvertidoUSD
        let rendimientoTotal = totalInvertidoUSD > 0 ? ((valorActualUSD - totalInvertidoUSD) / totalInvertidoUSD) * 100 : 0
        
        return MainPortfolioSummary(
            totalInvertidoUSD: totalInvertidoUSD,
            valorActualUSD: valorActualUSD,
            totalVentasUSD: totalVentasUSD,
            gananciaTotal: gananciaTotal,
            rendimientoTotal: rendimientoTotal
        )
    }
    
    static func calcularDistribucionGanancias(portfolioDetails: [CarteraDetail]) -> [MainCryptoDistribution] {
        // Agrupar todas las cryptos del portfolio
        var cryptoGanancias: [UUID: (nombre: String, ganancia: Decimal, valorTotal: Decimal)] = [:]
        
        for carteraDetail in portfolioDetails {
            for cryptoDetail in carteraDetail.cryptoDetails {
                if let existingData = cryptoGanancias[cryptoDetail.crypto.id] {
                    cryptoGanancias[cryptoDetail.crypto.id] = (
                        nombre: existingData.nombre,
                        ganancia: existingData.ganancia + cryptoDetail.ganancia,
                        valorTotal: existingData.valorTotal + cryptoDetail.valorUSD
                    )
                } else {
                    cryptoGanancias[cryptoDetail.crypto.id] = (
                        nombre: cryptoDetail.crypto.simbolo,
                        ganancia: cryptoDetail.ganancia,
                        valorTotal: cryptoDetail.valorUSD
                    )
                }
            }
        }
        
        // Calcular el total absoluto para los porcentajes
        let totalAbsoluto = cryptoGanancias.values.reduce(Decimal(0)) { $0 + abs($1.ganancia) }
        
        // Convertir a array y ordenar por ganancia
        return cryptoGanancias.map { (id, data) in
            let porcentaje = totalAbsoluto != 0 ? (data.ganancia / totalAbsoluto) * 100 : 0
            
            return MainCryptoDistribution(
                cryptoId: id,
                nombre: data.nombre,
                ganancia: data.ganancia,
                valorTotal: data.valorTotal,
                porcentaje: porcentaje
            )
        }.sorted { $0.ganancia > $1.ganancia }
    }
}
