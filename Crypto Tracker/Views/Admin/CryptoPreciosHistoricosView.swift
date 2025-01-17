import SwiftUI
import SwiftData

struct CryptoPreciosHistoricosView: View {
    let crypto: Crypto
    @Environment(\.dismiss) private var dismiss
    
    private var historicos: [PrecioHistorico] {
        crypto.historicosPrecios.sorted { $0.fecha > $1.fecha }
    }
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Historial de Precios - \(crypto.simbolo)")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Cerrar") {
                    dismiss()
                }
            }
            .padding()
            
            // Debug info y contenido principal
            if historicos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeSystem)
                        .foregroundStyle(.secondary)
                    Text("Sin histórico de precios")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Total registros: \(historicos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                
                List(historicos, id: \.id) { historico in
                    HStack {
                        Text(historico.fecha.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(historico.precio.formatted(.currency(code: "USD")))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            print("DEBUG - Historial para \(crypto.simbolo):")
            print("DEBUG - Total registros: \(historicos.count)")
            for historico in historicos {
                print("DEBUG - Fecha: \(historico.fecha), Precio: \(historico.precio)")
            }
        }
    }
}

// MARK: - Vista del Botón de Historial
struct CryptoHistoryButton: View {
    let crypto: Crypto
    @Binding var showingHistory: Bool
    
    var body: some View {
        Button(action: { showingHistory = true }) {
            Label("Ver Historial de Precios", systemImage: "clock.arrow.circlepath")
                .foregroundColor(.blue)
        }
        .sheet(isPresented: $showingHistory) {
            CryptoPreciosHistoricosView(crypto: crypto)
        }
    }
}

// MARK: - Font Extension
extension Font {
    static let largeSystem = Font.system(size: 48)
}

#Preview {
    // Crear una vista de preview con datos de ejemplo
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Crypto.self, configurations: config)
    
    // Crear crypto de ejemplo
    let crypto = Crypto(nombre: "Bitcoin", simbolo: "BTC", precio: 45000)
    
    // Agregar algunos precios históricos
    let historico1 = PrecioHistorico(crypto: crypto, precio: 44000, fecha: Date().addingTimeInterval(-86400))
    let historico2 = PrecioHistorico(crypto: crypto, precio: 43000, fecha: Date().addingTimeInterval(-172800))
    
    return CryptoPreciosHistoricosView(crypto: crypto)
        .modelContainer(container)
}
