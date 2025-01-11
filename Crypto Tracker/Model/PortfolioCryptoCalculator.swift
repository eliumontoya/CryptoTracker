import Foundation
import SwiftData

// MARK: - Servicio de cálculo para el portafolio por crypto
class PortfolioCryptoCalculator {
    static func calcularResumenPorCrypto(carteras: [Cartera], cryptos: [Crypto]) -> [CryptoPortfolioSummary] {
        // Crear un resumen por cada crypto
        return cryptos.map { crypto -> CryptoPortfolioSummary? in
            // Calcular total disponible sumando los balances de todas las carteras
            let totalDisponible = carteras.reduce(Decimal(0)) { total, cartera in
                total + cartera.getCryptoDisponible(crypto: crypto)
            }
            
            // Si no hay movimientos para esta crypto, no la incluimos
            guard totalDisponible > 0 else { return nil }
            
            // Calcular total USD de ingresos (incluyendo swaps destino)
            let totalUSDIngresos = carteras.reduce(Decimal(0)) { total, cartera in
                let ingresosDirectos = cartera.movimientosIngreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.valorTotalUSD }
                
                let ingresosSwaps = cartera.swaps
                    .filter { $0.cryptoDestino?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + ($1.cantidadDestino * $1.precioUSDDestino) }
                
                return total + ingresosDirectos + ingresosSwaps
            }
            
            // Calcular total USD de ventas (incluyendo swaps origen)
            let totalUSDVentas = carteras.reduce(Decimal(0)) { total, cartera in
                let ventasDirectas = cartera.movimientosEgreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.valorTotalUSD }
                
                let ventasSwaps = cartera.swaps
                    .filter { $0.cryptoOrigen?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + ($1.cantidadOrigen * $1.precioUSDOrigen) }
                
                return total + ventasDirectas + ventasSwaps
            }
            
            // Calcular valor actual
            let valorActual = totalDisponible * crypto.precio
            
            // Calcular ganancia
            let ganancia = valorActual - totalUSDIngresos + totalUSDVentas
            
            return CryptoPortfolioSummary(
                crypto: crypto,
                totalDisponible: totalDisponible,
                precioActual: crypto.precio,
                totalUSDAdquirido: totalUSDIngresos,
                valorActualUSD: valorActual,
                totalUSDVentas: totalUSDVentas,
                gananciaUSD: ganancia
            )
        }
        .compactMap { $0 }
        .sorted { $0.valorActualUSD > $1.valorActualUSD }
    }
}
