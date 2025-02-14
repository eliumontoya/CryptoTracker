// MovimientoEntradaView.swift
import SwiftUI
import SwiftData

struct MovimientosEntradaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MovimientoIngreso.fecha, order: .reverse) private var movimientos: [MovimientoIngreso]
    @State private var showingAddSheet = false
    @State private var selectedMovimiento: MovimientoIngreso?
    
    @StateObject private var viewModel: MovimientoEntradaViewModel
 
        // Hacer el inicializador público
        init(viewModel: MovimientoEntradaViewModel) {
            _viewModel = StateObject(wrappedValue: viewModel)
        }
    
    
    var body: some View {
        List {
            ForEach(movimientos) { movimiento in
                MovimientoEntradaRowView(movimiento: movimiento)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMovimiento = movimiento
                    }
            }
            .onDelete(perform: deleteMovimientos)
        }
        .navigationTitle("Movimientos de Entrada")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Nuevo Movimiento", systemImage: "plus")
                }
            }
        }
        .sheet(item: $selectedMovimiento) { movimiento in
            NavigationStack {
                MovimientoEntradaFormView(
                    viewModel: MovimientoEntradaViewModel(
                        modelContext: modelContext,
                        movimiento: movimiento
                    )
                )
            }
            .frame(minWidth: 500, minHeight: 700)
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MovimientoEntradaFormView(
                    viewModel: MovimientoEntradaViewModel(
                        modelContext: modelContext
                    )
                )
            }
            .frame(minWidth: 500, minHeight: 700)
        }
    }
    
    private func deleteMovimientos(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(movimientos[index])
        }
    }
}

struct MovimientoEntradaRowView: View {
    let movimiento: MovimientoIngreso
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primera línea: Fecha y Crypto
            HStack {
                Text(movimiento.fecha.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                Spacer()
                if let crypto = movimiento.crypto {
                    Text(crypto.simbolo)
                        .font(.headline)
                }
            }
            
            // Segunda línea: Cantidad y Precio USD
            HStack {
                if let crypto = movimiento.crypto {
                    Text("Cantidad: \(movimiento.cantidadCrypto.formatted()) \(crypto.simbolo)")
                }
                Spacer()
                Text("Precio USD: \(movimiento.precioUSD.formatted(.currency(code: "USD")))")
            }
            .font(.subheadline)
            
            // Tercera línea: Cartera y totales
            HStack {
                if let cartera = movimiento.cartera {
                    Text("Cartera: \(cartera.nombre)")
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Total USD: \(movimiento.valorTotalUSD.formatted(.currency(code: "USD")))")
                    if movimiento.usaFiatAlterno,
                       let fiat = movimiento.fiatAlterno,
                       let valorFiat = movimiento.valorTotalFiatAlterno {
                        Text("Total \(fiat.simbolo): \(valorFiat.formatted(.currency(code: fiat.simbolo)))")
                            .foregroundStyle(.green)
                    }
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
