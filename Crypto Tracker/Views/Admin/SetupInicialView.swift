import SwiftUI
import SwiftData

struct SetupOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
    let createDestination: (ModelContext) -> AnyView
}

struct SetupInicialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 20)
    ]
    
    @State private var setupOptions: [SetupOption]
    @State private var selectedOption: SetupOption?
    @State private var showingDestination = false
    
    init() {
        _setupOptions = State(initialValue: [
            SetupOption(
                title: "Eliminar Datos Existentes",
                icon: "trash.circle.fill",
                description: "Elimina todos los datos almacenados en la aplicación",
                createDestination: { modelContext in
                    AnyView(EliminarDataView(modelContext: modelContext))
                }
            ),
            SetupOption(
                title: "Carga de Catálogos Iniciales",
                icon: "folder.circle.fill",
                description: "Carga los catálogos predeterminados de Cryptos, FIAT y Carteras",
                createDestination: { modelContext in
                    AnyView(CargaCatalogosView(modelContext: modelContext))
                }
            ),
            SetupOption(
                title: "Carga de Movimientos Iniciales",
                icon: "arrow.left.arrow.right.circle.fill",
                description: "Importa movimientos iniciales desde un archivo",
                createDestination: { modelContext in
                    AnyView(CargaMovimientosInicialesView(modelContext: modelContext))
                }
            ),
            SetupOption(
                title: "Realizar y Cargar Backup",
                icon: "externaldrive.badge.checkmark",
                description: "Realiza copias de seguridad o restaura datos desde un backup",
                createDestination: { _ in
                    AnyView(EmptyView())
                }
            )
        ])
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    optionsGridView
                }
            }
            .sheet(isPresented: $showingDestination) {
                sheetDestinationView
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
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Configuración Inicial")
                .font(.largeTitle)
                .bold()
            Text("Selecciona una opción para comenzar")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }
    
    private var optionsGridView: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(setupOptions) { option in
                SetupOptionCard(option: option)
                    .onTapGesture {
                        selectedOption = option
                        showingDestination = true
                    }
            }
        }
        .padding(.horizontal)
    }
    
    private var sheetDestinationView: some View {
        Group {
            if let selectedOption = selectedOption {
                selectedOption.createDestination(modelContext)
            } else {
                EmptyView()
            }
        }
    }
}

struct SetupOptionCard: View {
    let option: SetupOption
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: option.icon)
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text(option.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
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
