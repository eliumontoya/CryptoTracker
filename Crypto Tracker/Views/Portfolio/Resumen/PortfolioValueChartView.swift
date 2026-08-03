import SwiftUI
import Charts

struct PortfolioValueChartView: View {
    let snapshots: [PortfolioSnapshot]

    var body: some View {
        if snapshots.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No historical snapshots available")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            Chart(snapshots) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.date, unit: .day),
                    y: .value("Value", NSDecimalNumber(decimal: snapshot.totalUSD).doubleValue)
                )
                .foregroundStyle(.blue)

                AreaMark(
                    x: .value("Date", snapshot.date, unit: .day),
                    y: .value("Value", NSDecimalNumber(decimal: snapshot.totalUSD).doubleValue)
                )
                .foregroundStyle(.blue.opacity(0.1))
            }
            .frame(minHeight: 200)
        }
    }
}
