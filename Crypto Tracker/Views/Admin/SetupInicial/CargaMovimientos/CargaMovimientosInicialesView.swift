import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CargaMovimientosInicialesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // URLs de archivos
    @State private var movimientosEntradaURL: URL?
    @State private var movimientosSalidaURL: URL?
    @State private var movimientosEntreCarterasURL: URL?

    // Estados
    @State private var isLoading = false
    @State private var logs: [String] = []
    @State private var totalCargados = [String: Int]()
    
    // Estados para errores
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Queries para validar existencia de catálogos
    @Query private var cryptos: [Crypto]
    @Query private var carteras: [Cartera]
    @Query private var fiats: [FIAT]
    
    // Servicios
    private var entradaService: CargaMovimientosEntradaService?
    private var salidaService: CargaMovimientosSalidaService?
    
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
                if !hayCatalogosNecesarios {
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
                        url: $movimientosEntradaURL,
                        types: ExcelReader.validateExcelTypes()
                    )
                    
                    // Movimientos de Salida
                    FileSelectionRow(
                        title: "Movimientos de Salida",
                        subtitle: "Formato: Fecha (DD/MM/YYYY), ID_Cartera, Cripto, Crypto Salido, Precio USD Venta, USD Total Salido, FIAT Recibido, FIAT_Simbolo",
                        url: $movimientosSalidaURL,
                        types: ExcelReader.validateExcelTypes()
                    )
                    // Movimientos Entre Carteras
                            FileSelectionRow(
                                title: "Movimientos Entre Carteras",
                                subtitle: "Formato: Fecha (DD/MM/YYYY), ID_Cartera_Origen, ID_Cartera_Destino, Cripto, Monto Envio, Monto recibido, Comision",
                                url: $movimientosEntreCarterasURL,
                                types: ExcelReader.validateExcelTypes()
                            )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Botón de carga
                Button(action: cargarArchivos) {
                    if isLoading {
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
                .disabled(isLoading || !hayArchivosSeleccionados || !hayCatalogosNecesarios)
                .padding(.horizontal)
                
                // Área de logs
                if !logs.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Log de operaciones:")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logs, id: \.self) { log in
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
                if !totalCargados.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumen de carga:")
                            .font(.headline)
                        
                        ForEach(Array(totalCargados.keys.sorted()), id: \.self) { key in
                            if let total = totalCargados[key] {
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
                if totalCargados.isEmpty && logs.contains(where: { $0.contains("cartera") || $0.contains("crypto") }) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Carteras
                        VStack(alignment: .leading, spacing: 8) {
                            Text("IDs de Carteras disponibles:")
                                .font(.headline)
                            
                            ForEach(carteras) { cartera in
                                Text("• \(cartera.simbolo) → \(cartera.nombre)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Cryptos
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cryptos disponibles:")
                                .font(.headline)
                            
                            ForEach(cryptos) { crypto in
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") {
                    dismiss()
                }
                .disabled(isLoading)
            }
        }
    }
    
    private var hayArchivosSeleccionados: Bool {
            movimientosEntradaURL != nil ||
            movimientosSalidaURL != nil ||
            movimientosEntreCarterasURL != nil
        }
    
    private var hayCatalogosNecesarios: Bool {
        !cryptos.isEmpty && !carteras.isEmpty && !fiats.isEmpty
    }
    
    private func cargarArchivos() {
        isLoading = true
        totalCargados.removeAll()
        
        Task {
            do {
                // Cargar movimientos de entrada si existe el archivo
                if let url = movimientosEntradaURL {
                    let service = CargaMovimientosEntradaService(modelContext: modelContext, delegate: self)
                    let total = try await service.cargarMovimientos(desde: url)
                    DispatchQueue.main.async {
                        totalCargados["Movimientos de Entrada"] = total
                    }
                }
                
                // Cargar movimientos de salida si existe el archivo
                if let url = movimientosSalidaURL {
                    let service = CargaMovimientosSalidaService(modelContext: modelContext, delegate: self)
                    let total = try await service.cargarMovimientos(desde: url)
                    DispatchQueue.main.async {
                        totalCargados["Movimientos de Salida"] = total
                    }
                }
                
                // Cargar movimientos entre carteras si existe el archivo
                               if let url = movimientosEntreCarterasURL {
                                   let service = CargaMovimientosEntreCarterasService(modelContext: modelContext, delegate: self)
                                   let total = try await service.cargarMovimientos(desde: url)
                                   DispatchQueue.main.async {
                                       totalCargados["Movimientos Entre Carteras"] = total
                                   }
                               }
                
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
}

// MARK: - CargaMovimientosDelegate Implementation
extension CargaMovimientosInicialesView: CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String) {
        DispatchQueue.main.async {
            logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
        }
    }
    
    func didCompleteTask(_ type: String, total: Int) {
        DispatchQueue.main.async {
            totalCargados[type] = total
            isLoading = false
        }
    }
    
    func didEncounterError(_ error: Error) {
        DispatchQueue.main.async {
            if let excelError = error as? ExcelWorksheetError {
                errorMessage = excelError.errorDescription ?? "Error desconocido"
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
            isLoading = false
            logs.append("❌ ERROR: \(errorMessage)")
        }
    }
}

#Preview {
    CargaMovimientosInicialesView()
        .frame(width: 800, height: 800)
        .withPreviewContainer()
}
