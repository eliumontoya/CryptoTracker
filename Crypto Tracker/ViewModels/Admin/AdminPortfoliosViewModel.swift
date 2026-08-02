import SwiftUI
import SwiftData
import Combine

enum PortfolioFormState: Identifiable {
    case add
    case edit(Portfolio)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let portfolio):
            return portfolio.id.uuidString
        }
    }
}

@MainActor
class AdminPortfoliosViewModel: ObservableObject {
    @Published private(set) var portfolios: [Portfolio] = []
    @Published var formState: PortfolioFormState?
    @Published var showingDeleteAlert = false
    @Published var selectedPortfolio: Portfolio?
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadPortfolios()
    }
    
    func loadPortfolios() {
        let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\.nombre)])
        portfolios = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func addPortfolio(nombre: String, descripcion: String, isDefault: Bool) {
        if isDefault {
            clearDefaultFlag()
        }
        let newPortfolio = Portfolio(nombre: nombre, descripcion: descripcion, isDefault: isDefault)
        modelContext.insert(newPortfolio)
        saveContext()
        portfolios.append(newPortfolio)
        portfolios.sort { $0.nombre < $1.nombre }
    }
    
    func updatePortfolio(_ portfolio: Portfolio, nombre: String, descripcion: String, isDefault: Bool) {
        if isDefault {
            clearDefaultFlag(excluding: portfolio)
        }
        portfolio.nombre = nombre
        portfolio.descripcion = descripcion
        portfolio.isDefault = isDefault
        saveContext()
        if let index = portfolios.firstIndex(where: { $0.id == portfolio.id }) {
            portfolios[index] = portfolio
        }
        portfolios.sort { $0.nombre < $1.nombre }
    }
    
    func deletePortfolio(_ portfolio: Portfolio) {
        modelContext.delete(portfolio)
        saveContext()
        portfolios.removeAll { $0.id == portfolio.id }
    }
    
    func showAddForm() {
        formState = .add
    }
    
    func showEditForm(for portfolio: Portfolio) {
        formState = .edit(portfolio)
    }
    
    func closeForm() {
        formState = nil
    }
    
    func canDeletePortfolio(_ portfolio: Portfolio) -> Bool {
        portfolio.carteras.isEmpty
    }
    
    private func clearDefaultFlag(excluding excludedPortfolio: Portfolio? = nil) {
        let descriptor = FetchDescriptor<Portfolio>()
        guard let allPortfolios = try? modelContext.fetch(descriptor) else { return }
        for portfolio in allPortfolios where portfolio.isDefault && portfolio.id != excludedPortfolio?.id {
            portfolio.isDefault = false
        }
    }
    
    private func saveContext() {
        try? modelContext.save()
    }
}
