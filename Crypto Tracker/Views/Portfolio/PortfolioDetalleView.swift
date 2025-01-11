import SwiftUI
import SwiftData

struct CryptoCarteraSummary: Identifiable {
    var id: UUID { crypto.id }
    let crypto: Crypto
    var cantidadTotal: Decimal
    var valorTotalUSD: Decimal
    var inversionTotalUSD: Decimal
    
    var rentabilidad: Decimal {
        guard inversionTotalUSD > 0 else { return 0 }
        return ((valorTotalUSD - inversionTotalUSD) / inversionTotalUSD) * 100
    }
}

struct CarteraSummary: Identifiable {
    var id: UUID { cartera.id }
    let cartera: Cartera
    var cryptoSummaries: [CryptoCarteraSummary]
    
    var valorTotalUSD: Decimal {
        cryptoSummaries.reduce(0) { $0 + $1.valorTotalUSD }
    }
    
    var inversionTotalUSD: Decimal {
        cryptoSummaries.reduce(0) { $0 + $1.inversionTotalUSD }
    }
    
    var rentabilidadTotal: Decimal {
        guard inversionTotalUSD > 0 else { return 0 }
        return ((valorTotalUSD - inversionTotalUSD) / inversionTotalUSD) * 100
    }
}

struct PortfolioDetalleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cartera.nombre) private var carteras: [Cartera]
    @Query(sort: \Crypto.nombre) private var cryptos: [Crypto]
    
    @State private var carterasSummary: [CarteraSummary] = []
    
    var body: some View {
        List {
            ForEach(carterasSummary) { carteraSummary in
                Section {
                    CarteraHeaderView(summary: carteraSummary)
                    ForEach(carteraSummary.cryptoSummaries) { cryptoSummary in
                        CryptoSummaryRowView(summary: cryptoSummary)
                    }
                }
            }
        }
        .navigationTitle("Desglose por Carteras")
        .onAppear {
            calcularResumen()
        }
    }
    
    private func calcularResumen() {
        carterasSummary = carteras.map { cartera in
            let cryptoSummaries = cryptos.compactMap { crypto -> CryptoCarteraSummary? in
                // Movimientos de entrada
                let ingresos = cartera.movimientosIngreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
                
                let inversionUSD = cartera.movimientosIngreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.valorTotalUSD }
                
                // Movimientos de salida
                let egresos = cartera.movimientosEgreso
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadCrypto }
                
                // Transferencias entre carteras
                let transferenciasEntrada = cartera.movimientosEntrada
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(into: Decimal(0)) { $0 + $1.cantidadCryptoEntrada }
                
                let transferenciasSalida = cartera.movimientosSalida
                    .filter { $0.crypto?.id == crypto.id }
                    .reduce(into: Decimal(0)) { $0 + $1.cantidadCryptoSalida }
                
                // Swaps
                let swapsEntrada = cartera.swaps
                    .filter { $0.cryptoDestino?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadDestino }
                
                let swapsSalida = cartera.swaps
                    .filter { $0.cryptoOrigen?.id == crypto.id }
                    .reduce(Decimal(0)) { $0 + $1.cantidadOrigen }
                
                // Calcular balance total
                let cantidadTotal = ingresos + transferenciasEntrada + swapsEntrada -
                                  (egresos + transferenciasSalida + swapsSalida)
                
                // Si no hay movimientos o el balance es 0, no incluir este crypto
                guard cantidadTotal != 0 else { return nil }
                
                let valorTotalUSD = cantidadTotal * crypto.precio
                
                return CryptoCarteraSummary(
                    crypto: crypto,
                    cantidadTotal: cantidadTotal,
                    valorTotalUSD: valorTotalUSD,
                    inversionTotalUSD: inversionUSD
                )
            }
            
            return CarteraSummary(
                cartera: cartera,
                cryptoSummaries: cryptoSummaries
            )
        }
        // Filtrar carteras sin cryptos
        carterasSummary = carterasSummary.filter { !$0.cryptoSummaries.isEmpty }
    }
}

struct CarteraHeaderView: View {
    let summary: CarteraSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(summary.cartera.nombre)
                    .font(.headline)
                Spacer()
                Text(summary.valorTotalUSD.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            HStack {
                Text("Inversión: \(summary.inversionTotalUSD.formatted(.currency(code: "USD")))")
                Spacer()
                Text("Rentabilidad: \(summary.rentabilidadTotal.formatted(.number.precision(.fractionLength(2))))%")
                    .foregroundStyle(summary.rentabilidadTotal >= 0 ? .green : .red)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct CryptoSummaryRowView: View {
    let summary: CryptoCarteraSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.crypto.simbolo)
                    .font(.headline)
                Spacer()
                Text("Balance: \(summary.cantidadTotal.formatted()) \(summary.crypto.simbolo)")
                    .font(.subheadline)
            }
            
            HStack {
                Text("Inversión: \(summary.inversionTotalUSD.formatted(.currency(code: "USD")))")
                Spacer()
                Text("Valor: \(summary.valorTotalUSD.formatted(.currency(code: "USD")))")
                    .foregroundStyle(summary.valorTotalUSD >= summary.inversionTotalUSD ? .green : .red)
            }
            .font(.caption)
            
            if summary.inversionTotalUSD > 0 {
                HStack {
                    Spacer()
                    Text("Rentabilidad: \(summary.rentabilidad.formatted(.number.precision(.fractionLength(2))))%")
                        .font(.caption)
                        .foregroundStyle(summary.rentabilidad >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PortfolioDetalleView()
        .withPreviewContainer()
}
