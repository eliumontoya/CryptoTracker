import SwiftUI
import SwiftData

struct EliminarDataView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Environment(\.modelContext) private var environmentModelContext
    private let modelContext: ModelContext
    @StateObject private var viewModel: EliminarDataViewModel

    
    init(modelContext: ModelContext) {
            self.modelContext = modelContext
        _viewModel = StateObject(wrappedValue: EliminarDataViewModel(modelContext: modelContext))

        }
    
    // Estado para logs y otras propiedades
        @State private var showingConfirmation = false
        @State private var logs: [String] = []
        @State private var isDeleting = false
        @State private var deleteCompleted = false
    
   
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Warning Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                // Warning Title
                Text("¡ADVERTENCIA!")
                    .font(.title)
                    .bold()
                    .foregroundColor(.red)
                
                // Detailed Description
                Text("Todos los datos que se encuentran en la aplicación serán borrados y no podrán recuperarse. Esto implica todos los movimientos, información de carteras, cryptos, FIAT e históricos existentes.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Action Buttons
                if !viewModel.deleteCompleted {
                    VStack(spacing: 16) {
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancelar, no quiero Borrar")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: 300)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        
                        // Delete Button
                        Button(action: {
                            showingConfirmation = true
                        }) {
                            Text("Borrar Datos")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: 150)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .disabled(viewModel.isDeleting)
                    }
                }
                
                // Logs Area
                if !viewModel.logs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
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
                
                // Close Button
                if viewModel.deleteCompleted {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cerrar")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .alert("Confirmar Eliminación", isPresented: $showingConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Sí, Borrar Todo", role: .destructive) {
                Task {
                    await viewModel.borrarDatos()
                }
            }
        } message: {
            Text("¿Está completamente seguro que desea eliminar todos los datos? Esta acción no se puede deshacer.")
        }
    }
}

/*
#Preview {
    struct PreviewWrapper: View {
            let context: ModelContext
            
            init() {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try! ModelContainer(
                    for: Crypto.self,
                        Cartera.self,
                        FIAT.self,
                        MovimientoIngreso.self,
                        MovimientoEgreso.self,
                        MovimientoEntreCarteras.self,
                        MovimientoSwap.self,
                        PrecioHistorico.self,
                        CryptoSyncConfig.self,
                    configurations: config
                )
                self.context = container.mainContext
            }
            
            var body: some View {
                EliminarDataView(modelContext: context)
            }
        }
        
          return PreviewWrapper()
}
*/
