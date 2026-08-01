import Foundation

enum Format {
    // MARK: - Decimal
    static func usd(_ value: Decimal) -> String {
        currency(value, code: "USD")
    }

    static func currency(_ value: Decimal, code: String) -> String {
        value.formatted(.currency(code: code))
    }

    static func crypto(_ value: Decimal, symbol: String) -> String {
        "\(value.formatted(.number)) \(symbol)"
    }

    static func percent(_ value: Decimal) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2))))%"
    }

    // MARK: - Double
    static func usd(_ value: Double) -> String {
        currency(value, code: "USD")
    }

    static func currency(_ value: Double, code: String) -> String {
        value.formatted(.currency(code: code))
    }

    static func crypto(_ value: Double, symbol: String) -> String {
        "\(value.formatted(.number)) \(symbol)"
    }

    static func percent(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2))))%"
    }

    // MARK: - Date
    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
