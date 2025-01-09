import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var carteras: [Cartera]
    @Query private var cryptos: [Crypto]
    
    var body: some View {
        VStack {
            Text("Portfolio")
                .font(.title)
                .padding()
            
            // Por ahora solo mostraremos placeholders
            HStack {
                VStack(alignment: .leading) {
                    Text("Valor Total del Portfolio")
                        .font(.headline)
                    Text("$0.00")
                        .font(.title)
                }
                Spacer()
            }
            .padding()
            
            Spacer()
            
            Text("Aquí irá el detalle del portfolio")
        }
        .navigationTitle("Portfolio")
        .padding()
    }
}

#Preview {
    PortfolioView()
}
