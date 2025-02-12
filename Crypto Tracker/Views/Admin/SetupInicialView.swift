import SwiftUI

struct SetupOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
    let destination: AnyView?
}

struct SetupInicialView: View {
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 20)
    ]
    
    @State private var setupOptions: [SetupOption] = [
        SetupOption(
            title: "Eliminar Datos Existentes",
            icon: "trash.circle.fill",
            description: "Elimina todos los datos almacenados en la aplicación",
            destination: AnyView(EliminarDataView())
        ),
        SetupOption(
            title: "Carga de Catálogos Iniciales",
            icon: "folder.circle.fill",
            description: "Carga los catálogos predeterminados de Cryptos, FIAT y Carteras",
            destination: AnyView(CargaCatalogosView())
        ),
        SetupOption(
            title: "Carga de Movimientos Iniciales",
            icon: "arrow.left.arrow.right.circle.fill",
            description: "Importa movimientos iniciales desde un archivo",
            destination: AnyView(CargaMovimientosInicialesView())
        ),
        SetupOption(
            title: "Realizar y Cargar Backup",
            icon: "externaldrive.badge.checkmark",
            description: "Realiza copias de seguridad o restaura datos desde un backup",
            destination: nil
        )
    ]
    
    @State private var selectedOption: SetupOption?
    @State private var showingDestination = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Configuración Inicial")
                            .font(.largeTitle)
                            .bold()
                        Text("Selecciona una opción para comenzar")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                    
                    // Grid de opciones
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(setupOptions) { option in
                            SetupOptionCard(option: option)
                                .onTapGesture {
                                    selectedOption = option
                                    if option.destination != nil {
                                        showingDestination = true
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .sheet(isPresented: $showingDestination) {
                if let destination = selectedOption?.destination {
                    destination
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SetupOptionCard: View {
    let option: SetupOption
    
    var body: some View {
        VStack(spacing: 16) {
            // Icono
            Image(systemName: option.icon)
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            // Título
            Text(option.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Descripción
            Text(option.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.1))
        )
    }
}

#Preview {
    SetupInicialView()
}
