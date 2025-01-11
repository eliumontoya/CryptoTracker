import SwiftUI
import SwiftData

// Estructura para mantener toda la información de una crypto en una cartera
struct CryptoDetail: Identifiable {
    var id: UUID { crypto.id }
    let crypto: Crypto
    var totalCryptoIngresado: Decimal    // Total de crypto ingresado (entradas + swaps destino)
    var totalCryptoVendido: Decimal      // Total de crypto vendido (salidas + swaps origen)
    var totalCryptoTransferido: Decimal  // Total de crypto transferido a otras carteras
    var balanceActual: Decimal
    var totalInvertidoUSD: Decimal       // Total USD invertido en entradas
    var valorUSD: Decimal
    var totalInvertidoFIAT: Decimal
    var valorActualFIAT: Decimal
    var ganancia: Decimal
    
    // Calcular el porcentaje de ganancia/pérdida
    var porcentajeGanancia: Decimal {
        guard totalInvertidoFIAT != 0 else { return 0 }
        return ((valorActualFIAT - totalInvertidoFIAT) / totalInvertidoFIAT) * 100
    }
}

// Estructura para mantener toda la información de una cartera
struct CarteraDetail: Identifiable {
    var id: UUID { cartera.id }
    let cartera: Cartera
    var cryptoDetails: [CryptoDetail]
    
    // Totales de la cartera
    var totalValorUSD: Decimal {
        cryptoDetails.reduce(0) { $0 + $1.valorUSD }
    }
    
    var totalInvertidoFIAT: Decimal {
        cryptoDetails.reduce(0) { $0 + $1.totalInvertidoFIAT }
    }
    
    var totalValorFIAT: Decimal {
        cryptoDetails.reduce(0) { $0 + $1.valorActualFIAT }
    }
    
    var gananciaTotal: Decimal {
        cryptoDetails.reduce(0) { $0 + $1.ganancia }
    }
}

struct PortfolioDetalleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    @Query(sort: \FIAT.nombre) private var fiats: [FIAT]
    
    @State private var carterasDetail: [CarteraDetail] = []
    
    // Calcular cuántos renglones necesitamos (2 carteras por renglón)
    private var numeroRenglones: Int {
        (carterasDetail.count + 1) / 2
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<numeroRenglones, id: \.self) { renglon in
                    HStack(alignment: .top, spacing: 20) {
                        // Primera columna del renglón
                        if renglon * 2 < carterasDetail.count {
                            CarteraDetailView(carteraDetail: carterasDetail[renglon * 2])
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Segunda columna del renglón
                        if (renglon * 2 + 1) < carterasDetail.count {
                            CarteraDetailView(carteraDetail: carterasDetail[renglon * 2 + 1])
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Desglose por Carteras")
        .onAppear {
            calcularDetalles()
        }
    }
    
    private func calcularDetalles() {
        carterasDetail = carteras.map { cartera in
            let cryptoDetails = cryptos.compactMap { crypto -> CryptoDetail? in
                // Calcular totales por crypto
                let ingresosPorEntradas = cartera.movimientosIngreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
                
                let ingresosPorSwaps = cartera.swaps
                    .filter { $0.cryptoDestino?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadDestino }
                    
                let totalCryptoIngresado = ingresosPorEntradas + ingresosPorSwaps
                
                let egresosPorVentas = cartera.movimientosEgreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
                    
                let egresosPorSwaps = cartera.swaps
                    .filter { $0.cryptoOrigen?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadOrigen }
                    
                let totalCryptoVendido = egresosPorVentas + egresosPorSwaps
                
                // Transferencias entre carteras (entradas y salidas)
                let transferenciasEntrada = cartera.movimientosEntrada
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadCryptoEntrada }
                
                let transferenciasSalida = cartera.movimientosSalida
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadCryptoSalida }
                    
                // Balance neto de transferencias (positivo = más entradas, negativo = más salidas)
                let balanceTransferencias = transferenciasEntrada - transferenciasSalida
                
                // Calcular balance total
                let balanceActual = totalCryptoIngresado + transferenciasEntrada -
                                  (totalCryptoVendido + transferenciasSalida)
                
                // Calcular total USD invertido en entradas
                let totalInvertidoUSD = cartera.movimientosIngreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.valorTotalUSD }

                // Si no hay movimientos, no incluir esta crypto
                guard balanceActual != 0 else { return nil }
                
                // Calcular valor actual en USD
                let valorUSD = balanceActual * crypto.precio
                
                // Calcular inversión total en FIAT
                let totalInvertidoFIAT = cartera.movimientosIngreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { total, movimiento in
                        if movimiento.usaFiatAlterno,
                           let valorFiat = movimiento.valorTotalFiatAlterno {
                            return total + valorFiat
                        } else {
                            return total + movimiento.valorTotalUSD
                        }
                    }
                
                // Calcular valor actual en FIAT (usando el primer FIAT disponible)
                let fiat = fiats.first
                let valorActualFIAT = valorUSD * (fiat?.precioUSD ?? 1)
                
                return CryptoDetail(
                    crypto: crypto,
                    totalCryptoIngresado: totalCryptoIngresado,
                    totalCryptoVendido: totalCryptoVendido,
                    totalCryptoTransferido: balanceTransferencias,
                    balanceActual: balanceActual,
                    totalInvertidoUSD: totalInvertidoUSD,
                    valorUSD: valorUSD,
                    totalInvertidoFIAT: totalInvertidoFIAT,
                    valorActualFIAT: valorActualFIAT,
                    ganancia: valorActualFIAT - totalInvertidoFIAT
                )
            }
            
            return CarteraDetail(
                cartera: cartera,
                cryptoDetails: cryptoDetails
            )
        }
        // Filtrar carteras sin cryptos
        carterasDetail = carterasDetail.filter { !$0.cryptoDetails.isEmpty }
    }
}

struct CarteraDetailView: View {
    let carteraDetail: CarteraDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Encabezado de la cartera
            Text(carteraDetail.cartera.nombre)
                .font(.title2)
                .bold()
            
            // Totales de la cartera
            HStack {
                VStack(alignment: .leading) {
                    Text("Valor Total USD:")
                        .font(.caption)
                    Text(carteraDetail.totalValorUSD.formatted(.currency(code: "USD")))
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Ganancia Total:")
                        .font(.caption)
                    Text(carteraDetail.gananciaTotal.formatted(.currency(code: "USD")))
                        .foregroundColor(carteraDetail.gananciaTotal >= 0 ? .green : .red)
                        .bold()
                }
            }
            .padding(.bottom, 8)
            
            // Tabla de cryptos
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    // Encabezados de la tabla
                    HStack(spacing: 0) {
                        Text("Crypto")
                            .frame(width: 80, alignment: .leading)
                        Text("Ingresado")
                            .frame(width: 100, alignment: .trailing)
                        Text("Vendido")
                            .frame(width: 100, alignment: .trailing)
                        Text("Transfer.")
                            .frame(width: 100, alignment: .trailing)
                        Text("Balance")
                            .frame(width: 100, alignment: .trailing)
                        Text("USD Inv.")
                            .frame(width: 100, alignment: .trailing)
                        Text("Valor USD")
                            .frame(width: 100, alignment: .trailing)
                        Text("Ganancia")
                            .frame(width: 100, alignment: .trailing)
                        Text("%")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    
                    // Filas de datos
                    ForEach(carteraDetail.cryptoDetails) { detail in
                        HStack(spacing: 0) {
                            Text(detail.crypto.simbolo)
                                .frame(width: 80, alignment: .leading)
                            Text(detail.totalCryptoIngresado.formatted())
                                .frame(width: 100, alignment: .trailing)
                            Text(detail.totalCryptoVendido.formatted())
                                .frame(width: 100, alignment: .trailing)
                            Text(detail.totalCryptoTransferido.formatted())
                                .frame(width: 100, alignment: .trailing)
                                .foregroundColor(detail.totalCryptoTransferido >= 0 ? .green : .red)
                            Text(detail.balanceActual.formatted())
                                .frame(width: 100, alignment: .trailing)
                            Text(detail.totalInvertidoUSD.formatted(.currency(code: "USD")))
                                .frame(width: 100, alignment: .trailing)
                            Text(detail.valorUSD.formatted(.currency(code: "USD")))
                                .frame(width: 100, alignment: .trailing)
                            Text(detail.ganancia.formatted(.currency(code: "USD")))
                                .frame(width: 100, alignment: .trailing)
                                .foregroundColor(detail.ganancia >= 0 ? .green : .red)
                            Text(detail.porcentajeGanancia.formatted(.number.precision(.fractionLength(2))) + "%")
                                .frame(width: 80, alignment: .trailing)
                                .foregroundColor(detail.porcentajeGanancia >= 0 ? .green : .red)
                        }
                        .font(.callout)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    PortfolioDetalleView()
        .withPreviewContainer()
}
