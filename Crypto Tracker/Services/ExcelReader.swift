import Foundation
import UniformTypeIdentifiers
import CoreXLSX

// MARK: - ExcelWorksheetError
enum ExcelWorksheetError: LocalizedError {
    case fileNotFound(String)
    case invalidWorkbook(String)
    case invalidSheet(String)
    case noData(String)
    case invalidFormat(String)
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let detail):
            return "No se pudo encontrar o acceder al archivo: \(detail)"
        case .invalidWorkbook(let detail):
            return "El archivo Excel no es válido: \(detail)"
        case .invalidSheet(let detail):
            return "Error en la hoja de Excel: \(detail)"
        case .noData(let detail):
            return "No se encontraron datos: \(detail)"
        case .invalidFormat(let detail):
            return "Formato inválido: \(detail)"
        case .parsingError(let detail):
            return "Error al procesar el archivo: \(detail)"
        }
    }
}
extension ExcelWorksheet {
    // Inicializador para pruebas
    init(testHeaderRow: [String], testRows: [[String]]) {
        self.headerRow = testHeaderRow
        self.rows = testRows
    }
}

// MARK: - ExcelWorksheet
struct ExcelWorksheet {
    let rows: [[String]]
    let headerRow: [String]
    
    init(xlsxFile: XLSXFile) throws {
        print("📊 Iniciando lectura del archivo Excel...")
        
        // Obtener las hojas disponibles
        print("📑 Obteniendo hojas del archivo...")
        let paths = try xlsxFile.parseWorksheetPaths()
        guard let worksheetPath = paths.first else {
            throw ExcelWorksheetError.invalidSheet("No se encontraron hojas en el archivo")
        }
        print("✓ Encontradas \(paths.count) hojas")
        
        // Obtener la primera hoja
        print("📄 Leyendo primera hoja...")
        let worksheet = try xlsxFile.parseWorksheet(at: worksheetPath)
        
        // Obtener strings compartidos si existen
        print("🔤 Procesando strings compartidos...")
        let sharedStrings = try? xlsxFile.parseSharedStrings()
        if sharedStrings != nil {
            print("✓ Strings compartidos encontrados")
        } else {
            print("⚠️ No se encontraron strings compartidos")
        }
        
        // Procesar todas las filas
        print("📝 Procesando filas...")
        var allRows: [[String]] = []
        
        if let rows = worksheet.data?.rows {
            print("✓ Encontradas \(rows.count) filas")
            allRows = rows.map { row in
                let valuesByColumn = Dictionary(uniqueKeysWithValues: row.cells.map { cell in
                    let value: String
                    if let sharedStrings {
                        value = cell.stringValue(sharedStrings) ?? ""
                    } else {
                        value = cell.value ?? ""
                    }
                    return (cell.reference.column.description, value)
                })
                return Self.alignedRow(valuesByColumn: valuesByColumn)
            }
            print("✓ Procesadas \(allRows.count) filas")
        } else {
            throw ExcelWorksheetError.noData("No se encontraron filas en la hoja")
        }
        
        guard !allRows.isEmpty else {
            throw ExcelWorksheetError.noData("El archivo está vacío")
        }
        
        // Procesar encabezados
        print("🏷 Procesando encabezados...")
        let headerRow = allRows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        self.headerRow = headerRow
        print("✓ Encabezados encontrados: \(headerRow.joined(separator: ", "))")
        
        // Procesar datos
        self.rows = allRows.dropFirst().map { row in
            if row.count >= headerRow.count {
                return Array(row.prefix(headerRow.count))
            }
            return row + Array(repeating: "", count: headerRow.count - row.count)
        }
        print("✅ Lectura completada. Total filas de datos: \(self.rows.count)")
    }
    
    func validateHeaders(_ requiredHeaders: [String]) throws {
        print("🔍 Validando encabezados requeridos: \(requiredHeaders.joined(separator: ", "))")
        let missingHeaders = requiredHeaders.filter { !headerRow.contains($0) }
        if !missingHeaders.isEmpty {
            throw ExcelWorksheetError.invalidFormat("""
                Faltan las siguientes columnas requeridas: 
                \(missingHeaders.joined(separator: ", "))
                
                Encabezados encontrados:
                \(headerRow.joined(separator: ", "))
                """)
        }
        print("✓ Todos los encabezados requeridos están presentes")
    }
    
    func columnIndex(for header: String) -> Int? {
        return headerRow.firstIndex(of: header)
    }

    static func alignedRow(valuesByColumn: [String: String]) -> [String] {
        let indexedValues = valuesByColumn.compactMap { column, value -> (Int, String)? in
            guard let index = columnIndex(for: column) else { return nil }
            return (index, value)
        }
        guard let lastIndex = indexedValues.map(\.0).max() else { return [] }

        var values = Array(repeating: "", count: lastIndex + 1)
        for (index, value) in indexedValues {
            values[index] = value
        }
        return values
    }

    private static func columnIndex(for reference: String) -> Int? {
        guard !reference.isEmpty else { return nil }
        var result = 0
        for scalar in reference.uppercased().unicodeScalars {
            guard scalar.value >= 65, scalar.value <= 90 else { return nil }
            result = result * 26 + Int(scalar.value - 64)
        }
        return result - 1
    }
}

// MARK: - ExcelReader
class ExcelReader {
    static func read(from url: URL) async throws -> ExcelWorksheet {
        print("📂 Iniciando lectura desde: \(url.lastPathComponent)")

        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        guard accessedSecurityScope || FileManager.default.isReadableFile(atPath: url.path) else {
            throw ExcelWorksheetError.fileNotFound("No se pudo acceder al archivo \"\(url.lastPathComponent)\". Seleccione el archivo nuevamente.")
        }
        defer { if accessedSecurityScope {
            url.stopAccessingSecurityScopedResource()
        } }

        guard let xlsxFile = XLSXFile(filepath: url.path) else {
            throw ExcelWorksheetError.invalidWorkbook("No se pudo abrir el archivo. Verifique que sea un archivo Excel válido (.xlsx)")
        }

        do {
            return try ExcelWorksheet(xlsxFile: xlsxFile)
        } catch {
            print("❌ Error al procesar el archivo: \(error.localizedDescription)")
            throw ExcelWorksheetError.parsingError("Error al procesar el archivo: \(error.localizedDescription)")
        }
    }
    
    static func validateExcelTypes() -> [UTType] {
        return [
            UTType(filenameExtension: "xlsx")!
        ]
    }
}

// MARK: - Helper Extensions
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
