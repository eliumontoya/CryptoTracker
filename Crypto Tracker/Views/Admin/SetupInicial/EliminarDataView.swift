import SwiftUI
import SwiftData

struct EliminarDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingConfirmation = false
    @State private var logs: [String] = []
    @State private var isDeleting = false
    @State private var deleteCompleted = false
    
    // Queries para obtener todos los datos
    @Query private var cryptos: [Crypto]
    @Query private var carteras: [Cartera]
    @Query private var fiats: [FIAT]
    @Query private var movimientosIngreso: [MovimientoIngreso]
    @Query private var movimientosEgreso: [MovimientoEgreso]
    @Query private var movimientosEntreCarteras: [MovimientoEntreCarteras]
    @Query private var movimientosSwap: [MovimientoSwap]
    @Query private var preciosHistoricos: [PrecioHistorico]
    @Query private var syncConfigs: [CryptoSyncConfig]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Ícono de advertencia
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                // Texto de advertencia
                Text("¡ADVERTENCIA!")
                    .font(.title)
                    .bold()
                    .foregroundColor(.red)
                
                // Descripción detallada
                Text("Todos los datos que se encuentran en la aplicación serán borrados y no podrán recuperarse. Esto implica todos los movimientos, información de carteras, cryptos, FIAT e históricos existentes.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Botones de acción
                if !deleteCompleted {
                    VStack(spacing: 16) {
                        // Botón de cancelar (más prominente)
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
                        
                        // Botón de borrado (más discreto)
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
                        .disabled(isDeleting)
                    }
                }
                
                // Área de logs
                if !logs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
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
                
                // Botón Cerrar (aparece solo cuando se completa el borrado)
                if deleteCompleted {
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
                    await borrarDatos()
                }
            }
        } message: {
            Text("¿Está completamente seguro que desea eliminar todos los datos? Esta acción no se puede deshacer.")
        }
    }
    
    private func agregarLog(_ mensaje: String) {
        DispatchQueue.main.async {
            logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(mensaje)")
        }
    }
    
    private func borrarDatos() async {
        isDeleting = true
        
        // Borrando movimientos
        agregarLog("Iniciando borrado de datos...")
        
        // Movimientos
        agregarLog("Borrando movimientos de ingreso...")
        for movimiento in movimientosIngreso {
            modelContext.delete(movimiento)
        }
        
        agregarLog("Borrando movimientos de egreso...")
        for movimiento in movimientosEgreso {
            modelContext.delete(movimiento)
        }
        
        agregarLog("Borrando movimientos entre carteras...")
        for movimiento in movimientosEntreCarteras {
            modelContext.delete(movimiento)
        }
        
        agregarLog("Borrando movimientos de swap...")
        for movimiento in movimientosSwap {
            modelContext.delete(movimiento)
        }
        
        // Históricos
        agregarLog("Borrando precios históricos...")
        for precio in preciosHistoricos {
            modelContext.delete(precio)
        }
        
        // Configuraciones
        agregarLog("Borrando configuraciones de sincronización...")
        for config in syncConfigs {
            modelContext.delete(config)
        }
        
        // Catálogos
        agregarLog("Borrando carteras...")
        for cartera in carteras {
            modelContext.delete(cartera)
        }
        
        agregarLog("Borrando cryptos...")
        for crypto in cryptos {
            modelContext.delete(crypto)
        }
        
        agregarLog("Borrando monedas FIAT...")
        for fiat in fiats {
            modelContext.delete(fiat)
        }
        
        do {
            try modelContext.save()
            agregarLog("✅ Borrado completado exitosamente")
            // Marcar como completado para mostrar el botón de cerrar
            DispatchQueue.main.async {
                deleteCompleted = true
            }
        } catch {
            agregarLog("❌ Error al guardar cambios: \(error.localizedDescription)")
        }
        
        isDeleting = false
    }
}

#Preview {
    EliminarDataView()
}
