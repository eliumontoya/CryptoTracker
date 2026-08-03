import SwiftUI
import SwiftData

struct AdminPortfoliosView: View {
    @StateObject private var viewModel: AdminPortfoliosViewModel
    
    init(viewModel: AdminPortfoliosViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        List {
            ForEach(viewModel.portfolios) { portfolio in
                PortfolioRowView(portfolio: portfolio)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedPortfolio = portfolio
                        viewModel.showEditForm(for: portfolio)
                    }
            }
            .onDelete { offsets in
                for index in offsets {
                    let portfolio = viewModel.portfolios[index]
                    if viewModel.canDeletePortfolio(portfolio) {
                        viewModel.deletePortfolio(portfolio)
                    } else {
                        viewModel.selectedPortfolio = portfolio
                        viewModel.showingDeleteAlert = true
                    }
                }
            }
        }
        .navigationTitle("Portfolios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showAddForm() }) {
                    Label("Add Portfolio", systemImage: "plus")
                }
            }
        }
        .sheet(item: $viewModel.formState) { formState in
            NavigationStack {
                PortfolioFormView(viewModel: viewModel, mode: formState)
            }
        }
        .alert("Delete Portfolio?", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let portfolio = viewModel.selectedPortfolio {
                    viewModel.deletePortfolio(portfolio)
                    viewModel.selectedPortfolio = nil
                }
            }
        } message: {
            Text("This portfolio has wallets assigned. Remove them first.")
        }
    }
}

struct PortfolioRowView: View {
    let portfolio: Portfolio
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(portfolio.nombre)
                    .font(.headline)
                if portfolio.isDefault {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                Spacer()
                Text("\(portfolio.carteras.count) wallets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !portfolio.descripcion.isEmpty {
                Text(portfolio.descripcion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PortfolioFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdminPortfoliosViewModel
    let mode: PortfolioFormState
    
    @State private var nombre: String = ""
    @State private var descripcion: String = ""
    @State private var isDefault: Bool = false
    
    var title: String {
        switch mode {
        case .add:
            return "New Portfolio"
        case .edit:
            return "Edit Portfolio"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Name", text: $nombre)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $descripcion)
                .textFieldStyle(.roundedBorder)
            Toggle("Default", isOn: $isDefault)
            
            Spacer()
        }
        .padding()
        .adaptiveSheetFrame(minWidth: 300, minHeight: 220)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.closeForm()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    viewModel.closeForm()
                    dismiss()
                }
                .disabled(nombre.isEmpty)
            }
        }
        .onAppear {
            if case .edit(let portfolio) = mode {
                nombre = portfolio.nombre
                descripcion = portfolio.descripcion
                isDefault = portfolio.isDefault
            }
        }
    }
    
    private func save() {
        switch mode {
        case .add:
            viewModel.addPortfolio(nombre: nombre, descripcion: descripcion, isDefault: isDefault)
        case .edit(let portfolio):
            viewModel.updatePortfolio(portfolio, nombre: nombre, descripcion: descripcion, isDefault: isDefault)
        }
    }
}
