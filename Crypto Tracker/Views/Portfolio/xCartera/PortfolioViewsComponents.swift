import SwiftUI

// MARK: - Tipo auxiliar para sheet
struct IdentifiableCryptoCarteraPair: Identifiable {
    let id = UUID()
    let crypto: Crypto
    let cartera: Cartera
}




// MARK: - Vistas Auxiliares de Portfolio
struct CarteraHeaderView: View {
    let summary: CarteraDetail
    
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
                Text("Inversión: \(summary.totalInvertidoFIAT.formatted(.currency(code: "USD")))")
                Spacer()
                Text("Rentabilidad: \(summary.rentabilidadTotal.formatted(.number.precision(.fractionLength(2))))%")
                    .foregroundStyle(summary.rentabilidadTotal >= 0 ? .green : .red)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct CarteraDetailView: View {
    let carteraDetail: CarteraDetail
    @State private var selectedCryptoDetail: (Crypto, Cartera)?
    @State private var showingCarteraMovimientos = false
    @State private var showingMovimientosMenu = false  // Para el menú de movimientos
    @State private var selectedMovimientoForm: MovimientoFormType?

        // Estados para los diferentes tipos de formularios
        @State private var showingEntradaForm = false
        @State private var showingSalidaForm = false
        @State private var showingEntreCarterasForm = false
        @State private var showingSwapForm = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            /*
            // Encabezado de la cartera (ahora clickeable)
            Button(action: { showingCarteraMovimientos = true }) {
                Text(carteraDetail.cartera.nombre)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)
            }
            */
            // Header con nombre de cartera y menú de nuevo movimiento
                        HStack {
                            Button(action: { showingCarteraMovimientos = true }) {
                                Text(carteraDetail.cartera.nombre)
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                            
                            Menu {
                                Button(action: { showingEntradaForm = true }) {
                                    Label("Nueva Entrada", systemImage: "arrow.down.circle")
                                }
                                
                                Button(action: { showingSalidaForm = true }) {
                                    Label("Nueva Salida", systemImage: "arrow.up.circle")
                                }
                                
                                Button(action: { showingEntreCarterasForm = true }) {
                                    Label("Nueva Transferencia", systemImage: "arrow.left.arrow.right")
                                }
                                
                                Button(action: { showingSwapForm = true }) {
                                    Label("Nuevo Swap", systemImage: "arrow.triangle.2.circlepath")
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
            
            
            // Totales de la cartera
            HStack {
                VStack(alignment: .leading) {
                    Text("Valor Total USD:")
                        .font(.caption)
                    Text(carteraDetail.valorTotalUSD.formatted(.currency(code: "USD")))
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
                        Button(action: {
                            selectedCryptoDetail = (detail.crypto, carteraDetail.cartera)
                        }) {
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
                        }
                        .buttonStyle(.plain)
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
        .sheet(item: Binding(
                    get: {
                        selectedCryptoDetail.map { crypto, cartera in
                            IdentifiableCryptoCarteraPair(crypto: crypto, cartera: cartera)
                        }
                    },
                    set: { pair in
                        selectedCryptoDetail = pair.map { ($0.crypto, $0.cartera) }
                    }
                )) { pair in
                    CarteraCryptoDetailView(crypto: pair.crypto, cartera: pair.cartera)
                }
                .sheet(isPresented: $showingCarteraMovimientos) {
                    CarteraMovimientosView(cartera: carteraDetail.cartera)
                }
                .sheet(isPresented: $showingEntradaForm) {
                    NavigationStack {
                        MovimientoEntradaFormView(mode: .add)
                            .onAppear {
                                // Preseleccionar la cartera actual
                                MovimientoEntradaFormView.preselectedCartera = carteraDetail.cartera
                            }
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
                .sheet(isPresented: $showingSalidaForm) {
                    NavigationStack {
                        MovimientoSalidaFormView(mode: .add)
                            .onAppear {
                                MovimientoSalidaFormView.preselectedCartera = carteraDetail.cartera
                            }
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
                .sheet(isPresented: $showingEntreCarterasForm) {
                    NavigationStack {
                        MovimientoEntreCarterasFormView(mode: .add)
                            .onAppear {
                                MovimientoEntreCarterasFormView.preselectedCarteraOrigen = carteraDetail.cartera
                            }
                    }
                    .frame(minWidth: 500, minHeight: 700)
                }
                .sheet(isPresented: $showingSwapForm) {
                    NavigationStack {
                        MovimientoSwapFormView(mode: .add)
                            .onAppear {
                                MovimientoSwapFormView.preselectedCartera = carteraDetail.cartera
                            }
                    }
                    .frame(minWidth: 500, minHeight: 700)
                    }
                
    }
}
