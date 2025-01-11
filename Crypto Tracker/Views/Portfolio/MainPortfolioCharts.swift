import SwiftUI

// MARK: - Componente de Gráfico Circular Principal
struct MainPieChartView: View {
    let data: [MainChartData]
    let size: CGFloat
    
    init(data: [MainChartData], size: CGFloat = 250) {
        self.data = data
        self.size = size
    }
    
    private var total: Double {
        data.reduce(0) { $0 + abs($1.valor) }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let sumBeforeIndex = data[0..<index].reduce(0) { $0 + abs($1.valor) }
        return .degrees(-90 + (sumBeforeIndex / total * 360))
    }
    
    private func endAngle(for index: Int) -> Angle {
        let sumThroughIndex = data[0...index].reduce(0) { $0 + abs($1.valor) }
        return .degrees(-90 + (sumThroughIndex / total * 360))
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, segment in
                if segment.valor != 0 {
                    Path { path in
                        let center = CGPoint(x: size/2, y: size/2)
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: size/2,
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            clockwise: false
                        )
                    }
                    .fill(segment.color)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Componente de Leyenda Principal
struct MainChartLegendView: View {
    let data: [MainChartData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                    
                    Text(item.nombre)
                        .font(.subheadline)
                    
                    Text(item.porcentaje.formatted(.number.precision(.fractionLength(2))) + "%")
                        .foregroundStyle(item.porcentaje >= 0 ? .green : .red)
                        .font(.subheadline)
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Contenedor de Gráfico Principal con Título
struct MainChartContainerView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 8)
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))
        )
    }
}
