import SwiftUI
import SwiftData
import UniformTypeIdentifiers
struct CargaCatalogosView: View {
    @Environment(\.modelContext) private var environmentModelContext
    @Environment(\.dismiss) private var dismiss
    
    // Estados para los archivos seleccionados
    @State private var carterasURL: URL?
    @State private var cryptosURL: URL?
    @State private var fiatURL: URL?
    @State private var syncURL: URL?
    
    // ViewModel
    @StateObject private var viewModel: CargaCatalogosViewModel
    
    // Tipos de archivo permitidos
    let csvType = UTType(filenameExtension: "csv")!
    
    private let modelContext: ModelContext

    // Inicializador con inyección de dependencias
    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        _viewModel = StateObject(wrappedValue: CargaCatalogosViewModel(modelContext: modelContext))
        

    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icono y título
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Carga de Catálogos Iniciales")
                    .font(.title)
                    .bold()
                
                Text("Seleccione los archivos CSV para cada catálogo. Los archivos deben tener el formato específico indicado.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Sección de selección de archivos
                VStack(spacing: 16) {
                    FileSelectionRow(
                        title: "Carteras",
                        subtitle: "Formato: Nombre,Simbolo",
                        url: $carterasURL,
                        type: csvType
                    )
                    
                    FileSelectionRow(
                        title: "Cryptos",
                        subtitle: "Formato: Nombre,Simbolo",
                        url: $cryptosURL,
                        type: csvType
                    )
                    
                    FileSelectionRow(
                        title: "FIAT",
                        subtitle: "Formato: Nombre,Simbolo,Precio",
                        url: $fiatURL,
                        type: csvType
                    )
                    
                    FileSelectionRow(
                        title: "Sync Manual",
                        subtitle: "Formato: Simbolo de Crypto,URL,Precio Default",
                        url: $syncURL,
                        type: csvType
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Botón de carga
                Button(action: {
                    Task {
                        await viewModel.cargarArchivos(
                            carterasURL: carterasURL,
                            cryptosURL: cryptosURL,
                            fiatURL: fiatURL,
                            syncURL: syncURL
                        )
                    }
                }) {
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
                .disabled(viewModel.isLoading || !hayArchivosSeleccionados)
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
    
    private var hayArchivosSeleccionados: Bool {
        carterasURL != nil || cryptosURL != nil || fiatURL != nil || syncURL != nil
    }
}

/*
 #Preview {
 CargaCatalogosView()
 .frame(width: 800, height: 600)
 .withPreviewContainer()
 }
 */
