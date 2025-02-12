import SwiftUI
import UniformTypeIdentifiers

/// Componente reutilizable para selección de archivos
struct FileSelectionRow: View {
    let title: String
    let subtitle: String
    @Binding var url: URL?
    let types: [UTType]  // Permite múltiples tipos de archivo
    
    // Constructor para un solo tipo (retrocompatibilidad)
    init(title: String, subtitle: String, url: Binding<URL?>, type: UTType) {
        self.title = title
        self.subtitle = subtitle
        self._url = url
        self.types = [type]
    }
    
    // Constructor para múltiples tipos
    init(title: String, subtitle: String, url: Binding<URL?>, types: [UTType]) {
        self.title = title
        self.subtitle = subtitle
        self._url = url
        self.types = types
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let url = url {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            if url != nil {
                Button(action: { url = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: seleccionarArchivo) {
                Label("Seleccionar", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func seleccionarArchivo() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = types
        
        if panel.runModal() == .OK {
            url = panel.url
        }
    }
}
