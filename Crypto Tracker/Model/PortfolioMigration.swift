import Foundation
import SwiftData

/// Migración de datos para el cambio de esquema v2 → v3.
///
/// El cambio de esquema en sí (nueva entidad `Portfolio`, `Cartera.isMain`,
/// relación `Cartera.portfolio`) es aditivo y SwiftData lo migra de forma
/// ligera. Este helper completa la migración de datos: crea el portafolio
/// por defecto "Portafolio Principal" y asigna a él todas las carteras
/// huérfanas (sin portafolio).
///
/// Es idempotente: se puede ejecutar en cada arranque sin efectos secundarios
/// cuando ya no quedan carteras huérfanas o el portafolio por defecto existe.
@MainActor
enum PortfolioMigration {
    static let defaultPortfolioName = "Portafolio Principal"

    /// Crea el portafolio por defecto (si no existe) y vincula a él todas las
    /// carteras sin portafolio.
    @discardableResult
    static func apply(in context: ModelContext) -> Portfolio? {
        let carteras = (try? context.fetch(FetchDescriptor<Cartera>())) ?? []
        let portfolios = (try? context.fetch(FetchDescriptor<Portfolio>())) ?? []

        // Determinar el portafolio por defecto: el marcado como default, o el
        // primero existente, o crear uno nuevo.
        let defaultPortfolio: Portfolio
        if let existing = portfolios.first(where: { $0.isDefault }) {
            defaultPortfolio = existing
        } else if let first = portfolios.first {
            defaultPortfolio = first
        } else {
            let newPortfolio = Portfolio(nombre: defaultPortfolioName, isDefault: true)
            context.insert(newPortfolio)
            defaultPortfolio = newPortfolio
        }

        // Asignar carteras huérfanas al portafolio por defecto.
        var changed = false
        for cartera in carteras where cartera.portfolio == nil {
            cartera.portfolio = defaultPortfolio
            changed = true
        }

        if changed {
            try? context.save()
        }
        return defaultPortfolio
    }
}
