import SwiftUI
import UniformTypeIdentifiers

/// Componente reutilizable para selección de archivos
struct FileSelectionRow: View {
    let title: String
    let subtitle: String
    @Binding var url: URL?
    let types: [UTType]  // Permite múltiples tipos de archivo
    
    @State private var isShowingFileImporter = false
    
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
            
            Button(action: { isShowingFileImporter = true }) {
                Label("Seleccionar", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: types) { result in
            switch result {
            case .success(let selectedURL):
                url = selectedURL
            case .failure(let error):
                print("❌ Error al seleccionar archivo: \(error.localizedDescription)")
            }
        }
    }
}
