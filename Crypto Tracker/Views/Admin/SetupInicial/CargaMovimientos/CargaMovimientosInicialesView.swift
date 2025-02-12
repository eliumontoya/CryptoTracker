import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CargaMovimientosInicialesView: View {
    @Environment(\.modelContext) private var environmentModelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: CargaMovimientosViewModel
    private let modelContext: ModelContext

    // Initializer
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = StateObject(wrappedValue: CargaMovimientosViewModel(modelContext: modelContext))

    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Encabezado
                VStack {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Carga de Movimientos Iniciales")
                        .font(.title)
                        .bold()
                    
                    Text("""
                        Seleccione los archivos Excel con los movimientos a cargar.
                        Asegúrese de que los archivos sigan el formato especificado.
                        Note que para las carteras y cryptos debe usar el ID/Símbolo configurado.
                        """)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                // Validación de catálogos
                if !viewModel.hayCatalogosNecesarios {
                    VStack(spacing: 8) {
                        Label("Catálogos incompletos", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.headline)
                        
                        Text("Antes de cargar movimientos, asegúrese de tener cargados los catálogos de Cryptos, Carteras y FIAT.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Sección de selección de archivos
                VStack(spacing: 16) {
                    // Movimientos de Entrada
                    FileSelectionRow(
                        title: "Movimientos de Entrada",
                        subtitle: "Formato: Fecha (DD/MM/YYYY), ID_Cartera, Cripto, Cripto adquirido, USD Invertido, Costo Cripto/USD, FIAT Invertido, FIAT_Simbolo",
                        url: $viewModel.movimientosEntradaURL,
                        types: ExcelReader.validateExcelTypes()
                    )
                    
                    // Movimientos de Salida
                    FileSelectionRow(
                        title: "Movimientos de Salida",
                        subtitle: "Formato: Fecha (DD/MM/YYYY), ID_Cartera, Cripto, Crypto Salido, Precio USD Venta, USD Total Salido, FIAT Recibido, FIAT_Simbolo",
                        url: $viewModel.movimientosSalidaURL,
                        types: ExcelReader.validateExcelTypes()
                    )
                    
                    // Movimientos Entre Carteras
                    FileSelectionRow(
                        title: "Movimientos Entre Carteras",
                        subtitle: "Formato: Fecha (DD/MM/YYYY), ID_Cartera_Origen, ID_Cartera_Destino, Cripto, Monto Envio, Monto recibido, Comision",
                        url: $viewModel.movimientosEntreCarterasURL,
                        types: ExcelReader.validateExcelTypes()
                    )
                    
                    // Movimientos Swap
                    FileSelectionRow(
                        title: "Movimientos Swap",
                        subtitle: "Formato: Fecha (DD/MM/YYYY), ID_Cartera, Cripto origen, Monto Descontado, Cripto final, Monto Adquirido, precio de venta, precio de compra",
                        url: $viewModel.movimientosSwapURL,
                        types: ExcelReader.validateExcelTypes()
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Botón de carga
                Button(action: viewModel.cargarArchivos) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Iniciar Carga")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.hayArchivosSeleccionados || !viewModel.hayCatalogosNecesarios)
                .padding(.horizontal)
                
                // Área de logs
                if !viewModel.logs.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Log de operaciones:")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.logs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .padding()
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Resumen de carga
                if !viewModel.totalCargados.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumen de carga:")
                            .font(.headline)
                        
                        ForEach(Array(viewModel.totalCargados.keys.sorted()), id: \.self) { key in
                            if let total = viewModel.totalCargados[key] {
                                Text("\(key): \(total) registros cargados")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Ayuda con IDs
                if viewModel.totalCargados.isEmpty && viewModel.logs.contains(where: { $0.contains("cartera") || $0.contains("crypto") }) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Carteras
                        VStack(alignment: .leading, spacing: 8) {
                            Text("IDs de Carteras disponibles:")
                                .font(.headline)
                            
                            ForEach(viewModel.carteras) { cartera in
                                Text("• \(cartera.simbolo) → \(cartera.nombre)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Cryptos
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cryptos disponibles:")
                                .font(.headline)
                            
                            ForEach(viewModel.cryptos) { crypto in
                                Text("• \(crypto.simbolo) → \(crypto.nombre)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") {
                    dismiss()
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}
    /*
     #Preview {
     CargaMovimientosInicialesView()
     .frame(width: 800, height: 800)
     .withPreviewContainer()
     }
     */
