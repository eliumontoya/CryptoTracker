import Foundation
import SwiftData

// MARK: - Extensiones de validación
extension String {
    func validated(maxLength: Int) -> String {
        String(self.prefix(maxLength))
    }
}

// MARK: - Tipo de Movimiento
/// Tipo unificado de movimiento. El `rawValue` es la fuente de verdad para
/// persistencia, filtrado y display.
enum TipoMovimiento: String, Codable, CaseIterable, Sendable {
    case entrada
    case salida
    case transferenciaEntrada
    case transferenciaSalida
    case swapEntrada
    case swapSalida
    case ajuste
    case comision

    /// Título corto para la UI.
    var title: String {
        switch self {
        case .entrada: return "Entrada"
        case .salida: return "Salida"
        case .transferenciaEntrada, .transferenciaSalida: return "Transferencia"
        case .swapEntrada, .swapSalida: return "Swap"
        case .ajuste: return "Ajuste"
        case .comision: return "Comisión"
        }
    }

    /// Icono SF Symbols para la UI.
    var icon: String {
        switch self {
        case .entrada, .transferenciaEntrada, .swapEntrada: return "arrow.down.circle.fill"
        case .salida, .transferenciaSalida, .swapSalida: return "arrow.up.circle.fill"
        case .ajuste: return "slider.horizontal.3"
        case .comision: return "percent"
        }
    }

    /// Nombre de color semántico (ver MovimientoComponents / row views).
    var colorName: String {
        switch self {
        case .entrada, .transferenciaEntrada, .swapEntrada: return "green"
        case .salida, .transferenciaSalida, .swapSalida: return "red"
        case .ajuste: return "blue"
        case .comision: return "orange"
        }
    }

    /// `true` cuando el movimiento incrementa el balance de la cartera afectada.
    var increasesBalance: Bool {
        switch self {
        case .entrada, .transferenciaEntrada, .swapEntrada: return true
        case .salida, .transferenciaSalida, .swapSalida, .ajuste, .comision: return false
        }
    }
}

// MARK: - Entidad FIAT
@Model
class FIAT {
    @Attribute(.unique) var id: UUID
    var nombre: String {
        didSet { nombre = nombre.validated(maxLength: 20) }
    }
    var simbolo: String {
        didSet { simbolo = simbolo.validated(maxLength: 10) }
    }
    var precioUSD: Decimal

    @Relationship(inverse: \Movimiento.fiatAlterno) var movimientos: [Movimiento] = []
    // Deprecado: solo para migración v3 → v4
    @Relationship(inverse: \MovimientoIngreso.fiatAlterno) var movimientosIngreso: [MovimientoIngreso] = []
    @Relationship(inverse: \MovimientoEgreso.fiatAlterno) var movimientosEgreso: [MovimientoEgreso] = []

    init(nombre: String, simbolo: String, precioUSD: Decimal) {
        self.id = UUID()
        self.nombre = nombre.validated(maxLength: 20)
        self.simbolo = simbolo.validated(maxLength: 10)
        self.precioUSD = precioUSD
        self.movimientos = []
        self.movimientosIngreso = []
        self.movimientosEgreso = []
    }
}

// MARK: - Entidad Crypto
@Model
class Crypto {
    @Attribute(.unique) var id: UUID
    var nombre: String {
        didSet { nombre = nombre.validated(maxLength: 20) }
    }
    var simbolo: String {
        didSet { simbolo = simbolo.validated(maxLength: 10) }
    }
    var precio: Decimal
    var ultimaActualizacion: Date

    @Relationship(inverse: \Movimiento.crypto) var movimientos: [Movimiento] = []
    @Relationship(inverse: \Movimiento.cryptoOrigen) var movimientosComoCryptoOrigen: [Movimiento] = []
    @Relationship(inverse: \Movimiento.cryptoDestino) var movimientosComoCryptoDestino: [Movimiento] = []
    // Deprecado: solo para migración v3 → v4
    @Relationship(inverse: \MovimientoIngreso.crypto) var movimientosIngreso: [MovimientoIngreso] = []
    @Relationship(inverse: \MovimientoEgreso.crypto) var movimientosEgreso: [MovimientoEgreso] = []
    @Relationship(inverse: \PrecioHistorico.crypto) var historicosPrecios: [PrecioHistorico] = []
    @Relationship(inverse: \MovimientoSwap.cryptoOrigen) var swapsComoOrigen: [MovimientoSwap] = []
    @Relationship(inverse: \MovimientoSwap.cryptoDestino) var swapsComoDestino: [MovimientoSwap] = []

    init(nombre: String, simbolo: String, precio: Decimal) {
        self.id = UUID()
        self.nombre = nombre.validated(maxLength: 20)
        self.simbolo = simbolo.validated(maxLength: 10)
        self.precio = precio
        self.ultimaActualizacion = Date()
        self.movimientos = []
        self.movimientosComoCryptoOrigen = []
        self.movimientosComoCryptoDestino = []
        self.movimientosIngreso = []
        self.movimientosEgreso = []
        self.historicosPrecios = []
        self.swapsComoOrigen = []
        self.swapsComoDestino = []
    }

    func precioEnFecha(_ fecha: Date) -> Decimal? {
        historicosPrecios
            .first { Calendar.current.isDate($0.fecha, inSameDayAs: fecha) }?
            .precio
    }

    func rendimientoDesde(_ fecha: Date) -> Decimal? {
        guard let precioAnterior = precioEnFecha(fecha) else { return nil }
        return ((precio - precioAnterior) / precioAnterior) * 100
    }
}

// MARK: - Entidad PrecioHistorico
@Model
class PrecioHistorico {
    @Attribute(.unique) var id: UUID
    var fecha: Date
    var precio: Decimal

    @Relationship var crypto: Crypto?

    init(crypto: Crypto, precio: Decimal, fecha: Date) {
        self.id = UUID()
        self.crypto = crypto
        self.precio = precio
        self.fecha = fecha
    }
}

// MARK: - Entidad Portfolio
@Model
class Portfolio {
    @Attribute(.unique) var id: UUID
    var nombre: String {
        didSet { nombre = nombre.validated(maxLength: 50) }
    }
    var descripcion: String {
        didSet { descripcion = descripcion.validated(maxLength: 200) }
    }
    var isDefault: Bool

    @Relationship(inverse: \Cartera.portfolio) var carteras: [Cartera] = []

    init(nombre: String, descripcion: String = "", isDefault: Bool = false) {
        self.id = UUID()
        self.nombre = nombre.validated(maxLength: 50)
        self.descripcion = descripcion.validated(maxLength: 200)
        self.isDefault = isDefault
        self.carteras = []
    }
}

// MARK: - Entidad Cartera
@Model
class Cartera {
    @Attribute(.unique) var id: UUID
    var nombre: String {
        didSet { nombre = nombre.validated(maxLength: 20) }
    }
    var simbolo: String {
        didSet { simbolo = simbolo.validated(maxLength: 10) }
    }
    var isMain: Bool = false
    @Relationship var portfolio: Portfolio?

    /// Movimientos unificados que afectan a esta cartera (cartera principal).
    @Relationship(inverse: \Movimiento.cartera) var movimientos: [Movimiento] = []
    @Relationship(inverse: \Movimiento.carteraOrigen) var movimientosComoOrigen: [Movimiento] = []
    @Relationship(inverse: \Movimiento.carteraDestino) var movimientosComoDestino: [Movimiento] = []
    // Deprecado: solo para migración v3 → v4
    @Relationship(inverse: \MovimientoIngreso.cartera) var movimientosIngreso: [MovimientoIngreso] = []
    @Relationship(inverse: \MovimientoEgreso.cartera) var movimientosEgreso: [MovimientoEgreso] = []
    @Relationship(inverse: \MovimientoEntreCarteras.carteraOrigen) var movimientosSalida: [MovimientoEntreCarteras] = []
    @Relationship(inverse: \MovimientoEntreCarteras.carteraDestino) var movimientosEntrada: [MovimientoEntreCarteras] = []
    @Relationship(inverse: \MovimientoSwap.cartera) var swaps: [MovimientoSwap] = []

    init(nombre: String, simbolo: String, isMain: Bool = false, portfolio: Portfolio? = nil) {
        self.id = UUID()
        self.nombre = nombre.validated(maxLength: 20)
        self.simbolo = simbolo.validated(maxLength: 10)
        self.isMain = isMain
        self.portfolio = portfolio
        self.movimientos = []
        self.movimientosComoOrigen = []
        self.movimientosComoDestino = []
        self.movimientosIngreso = []
        self.movimientosEgreso = []
        self.movimientosSalida = []
        self.movimientosEntrada = []
        self.swaps = []
    }
}

// MARK: - Entidad Holding
@Model
class Holding {
    @Attribute(.unique) var id: String
    var portfolio: Portfolio
    var cartera: Cartera
    var crypto: Crypto
    var cantidad: Decimal {
        didSet {
            if cantidad < 0 {
                cantidad = 0
            }
        }
    }
    var updatedAt: Date
    
    /// Compone el id único por tripleta portfolio/cartera/crypto.
    static func makeId(portfolio: Portfolio, cartera: Cartera, crypto: Crypto) -> String {
        "\(portfolio.id.uuidString)|\(cartera.id.uuidString)|\(crypto.id.uuidString)"
    }
    
    init(portfolio: Portfolio,
         cartera: Cartera,
         crypto: Crypto,
         cantidad: Decimal) {
        self.id = Holding.makeId(portfolio: portfolio, cartera: cartera, crypto: crypto)
        self.portfolio = portfolio
        self.cartera = cartera
        self.crypto = crypto
        self.cantidad = max(cantidad, 0)
        self.updatedAt = Date()
    }
}

// MARK: - Entidad MovimientoIngreso
// MARK: - Entidad Movimiento (unificado)
/// Entidad unificada de movimientos. Reemplaza a `MovimientoIngreso`,
/// `MovimientoEgreso`, `MovimientoEntreCarteras` y `MovimientoSwap`.
///
/// Un swap o transferencia se modela como **dos** registros que comparten
/// `groupId`: una pierna de salida (transferenciaSalida / swapSalida) y una de
/// entrada (transferenciaEntrada / swapEntrada). Cada pierna conserva además
/// toda la información de la operación para poder mostrarse de forma autónoma.
@Model
class Movimiento {
    @Attribute(.unique) var id: UUID
    var fecha: Date
    /// Raw value del enum `TipoMovimiento` (persistido para filtros y sorting).
    var tipoRaw: String
    /// Agrupa las piernas de una operación lógica (swap / transferencia).
    var groupId: UUID?

    // MARK: Campos comunes (entrada / salida)
    var cantidadCrypto: Decimal
    var precioUSD: Decimal
    var valorTotalUSD: Decimal
    var usaFiatAlterno: Bool
    var precioFiatAlterno: Decimal?
    var valorTotalFiatAlterno: Decimal?

    // MARK: Campos de transferencia
    var cantidadCryptoSalida: Decimal
    var cantidadCryptoEntrada: Decimal
    var cantidadCryptoComision: Decimal

    // MARK: Campos de swap
    var cantidadOrigen: Decimal
    var cantidadDestino: Decimal
    var precioUSDOrigen: Decimal
    var precioUSDDestino: Decimal

    // MARK: Relaciones
    // Nota: el inverse se declara SOLO en el lado de la colección
    // (Cartera/Crypto/FIAT), siguiendo el patrón del resto del modelo.
    @Relationship var cartera: Cartera?
    @Relationship var crypto: Crypto?
    @Relationship var fiatAlterno: FIAT?
    @Relationship var carteraOrigen: Cartera?
    @Relationship var carteraDestino: Cartera?
    @Relationship var cryptoOrigen: Crypto?
    @Relationship var cryptoDestino: Crypto?

    /// Tipo de movimiento (derivado de `tipoRaw`).
    var tipo: TipoMovimiento {
        get { TipoMovimiento(rawValue: tipoRaw) ?? .ajuste }
        set { tipoRaw = newValue.rawValue }
    }

    init(
        tipo: TipoMovimiento,
        fecha: Date = Date(),
        groupId: UUID? = nil,
        cantidadCrypto: Decimal = 0,
        precioUSD: Decimal = 0,
        valorTotalUSD: Decimal = 0,
        usaFiatAlterno: Bool = false,
        precioFiatAlterno: Decimal? = nil,
        valorTotalFiatAlterno: Decimal? = nil,
        cantidadCryptoSalida: Decimal = 0,
        cantidadCryptoEntrada: Decimal = 0,
        cantidadCryptoComision: Decimal = 0,
        cantidadOrigen: Decimal = 0,
        cantidadDestino: Decimal = 0,
        precioUSDOrigen: Decimal = 0,
        precioUSDDestino: Decimal = 0,
        cartera: Cartera? = nil,
        crypto: Crypto? = nil,
        fiatAlterno: FIAT? = nil,
        carteraOrigen: Cartera? = nil,
        carteraDestino: Cartera? = nil,
        cryptoOrigen: Crypto? = nil,
        cryptoDestino: Crypto? = nil
    ) {
        self.id = UUID()
        self.fecha = fecha
        self.tipoRaw = tipo.rawValue
        self.groupId = groupId
        self.cantidadCrypto = cantidadCrypto
        self.precioUSD = precioUSD
        self.valorTotalUSD = valorTotalUSD
        self.usaFiatAlterno = usaFiatAlterno
        self.precioFiatAlterno = precioFiatAlterno
        self.valorTotalFiatAlterno = valorTotalFiatAlterno
        self.cantidadCryptoSalida = cantidadCryptoSalida
        self.cantidadCryptoEntrada = cantidadCryptoEntrada
        self.cantidadCryptoComision = cantidadCryptoComision
        self.cantidadOrigen = cantidadOrigen
        self.cantidadDestino = cantidadDestino
        self.precioUSDOrigen = precioUSDOrigen
        self.precioUSDDestino = precioUSDDestino
        self.cartera = cartera
        self.crypto = crypto
        self.fiatAlterno = fiatAlterno
        self.carteraOrigen = carteraOrigen
        self.carteraDestino = carteraDestino
        self.cryptoOrigen = cryptoOrigen
        self.cryptoDestino = cryptoDestino
    }

    // MARK: - Factories

    /// Movimiento de compra de crypto (tipo `.entrada`).
    static func entrada(
        fecha: Date,
        cantidadCrypto: Decimal,
        precioUSD: Decimal,
        usaFiatAlterno: Bool = false,
        precioFiatAlterno: Decimal? = nil,
        valorTotalFiatAlterno: Decimal? = nil,
        cartera: Cartera,
        crypto: Crypto,
        fiatAlterno: FIAT? = nil
    ) -> Movimiento {
        Movimiento(
            tipo: .entrada,
            fecha: fecha,
            cantidadCrypto: cantidadCrypto,
            precioUSD: precioUSD,
            valorTotalUSD: cantidadCrypto * precioUSD,
            usaFiatAlterno: usaFiatAlterno,
            precioFiatAlterno: precioFiatAlterno,
            valorTotalFiatAlterno: valorTotalFiatAlterno,
            cartera: cartera,
            crypto: crypto,
            fiatAlterno: fiatAlterno
        )
    }

    /// Movimiento de venta de crypto (tipo `.salida`).
    static func salida(
        fecha: Date,
        cantidadCrypto: Decimal,
        precioUSD: Decimal,
        usaFiatAlterno: Bool = false,
        precioFiatAlterno: Decimal? = nil,
        valorTotalFiatAlterno: Decimal? = nil,
        cartera: Cartera,
        crypto: Crypto,
        fiatAlterno: FIAT? = nil
    ) -> Movimiento {
        Movimiento(
            tipo: .salida,
            fecha: fecha,
            cantidadCrypto: cantidadCrypto,
            precioUSD: precioUSD,
            valorTotalUSD: cantidadCrypto * precioUSD,
            usaFiatAlterno: usaFiatAlterno,
            precioFiatAlterno: precioFiatAlterno,
            valorTotalFiatAlterno: valorTotalFiatAlterno,
            cartera: cartera,
            crypto: crypto,
            fiatAlterno: fiatAlterno
        )
    }

    /// Par de movimientos de transferencia entre carteras (pierna salida + pierna
    /// entrada) que comparten `groupId`.
    static func transferencia(
        fecha: Date,
        cantidadCryptoSalida: Decimal,
        cantidadCryptoEntrada: Decimal,
        carteraOrigen: Cartera,
        carteraDestino: Cartera,
        crypto: Crypto
    ) -> (salida: Movimiento, entrada: Movimiento) {
        let groupId = UUID()
        let comision = cantidadCryptoSalida - cantidadCryptoEntrada
        let salida = Movimiento(
            tipo: .transferenciaSalida,
            fecha: fecha,
            groupId: groupId,
            cantidadCryptoSalida: cantidadCryptoSalida,
            cantidadCryptoEntrada: cantidadCryptoEntrada,
            cantidadCryptoComision: comision,
            cartera: carteraOrigen,
            crypto: crypto,
            carteraOrigen: carteraOrigen,
            carteraDestino: carteraDestino
        )
        let entrada = Movimiento(
            tipo: .transferenciaEntrada,
            fecha: fecha,
            groupId: groupId,
            cantidadCryptoSalida: cantidadCryptoSalida,
            cantidadCryptoEntrada: cantidadCryptoEntrada,
            cantidadCryptoComision: comision,
            cartera: carteraDestino,
            crypto: crypto,
            carteraOrigen: carteraOrigen,
            carteraDestino: carteraDestino
        )
        return (salida, entrada)
    }

    /// Par de movimientos de swap (pierna salida + pierna entrada) que comparten
    /// `groupId`. Ambas piernas conservan la información completa del swap.
    static func swap(
        fecha: Date,
        cantidadOrigen: Decimal,
        cantidadDestino: Decimal,
        precioUSDOrigen: Decimal,
        precioUSDDestino: Decimal,
        cartera: Cartera,
        cryptoOrigen: Crypto,
        cryptoDestino: Crypto
    ) -> (salida: Movimiento, entrada: Movimiento) {
        let groupId = UUID()
        let salida = Movimiento(
            tipo: .swapSalida,
            fecha: fecha,
            groupId: groupId,
            cantidadOrigen: cantidadOrigen,
            cantidadDestino: cantidadDestino,
            precioUSDOrigen: precioUSDOrigen,
            precioUSDDestino: precioUSDDestino,
            cartera: cartera,
            cryptoOrigen: cryptoOrigen,
            cryptoDestino: cryptoDestino
        )
        let entrada = Movimiento(
            tipo: .swapEntrada,
            fecha: fecha,
            groupId: groupId,
            cantidadOrigen: cantidadOrigen,
            cantidadDestino: cantidadDestino,
            precioUSDOrigen: precioUSDOrigen,
            precioUSDDestino: precioUSDDestino,
            cartera: cartera,
            cryptoOrigen: cryptoOrigen,
            cryptoDestino: cryptoDestino
        )
        return (salida, entrada)
    }
}

// MARK: - Entidad MovimientoIngreso (DEPRECADA)
/// ⚠️ Deprecado: se conserva temporalmente solo para la migración v3 → v4
/// (`MovimientoMigration`). No usar en código nuevo — usar `Movimiento`.
@Model
class MovimientoIngreso {
    @Attribute(.unique) var id: UUID
    var fecha: Date

    // Campos principales
    var cantidadCrypto: Decimal
    var precioUSD: Decimal
    var valorTotalUSD: Decimal

    // FIAT Alterno
    var usaFiatAlterno: Bool
    var precioFiatAlterno: Decimal?
    var valorTotalFiatAlterno: Decimal?

    // Relaciones
    @Relationship var cartera: Cartera?
    @Relationship var crypto: Crypto?
    @Relationship var fiatAlterno: FIAT?

    init(fecha: Date,
         cantidadCrypto: Decimal,
         precioUSD: Decimal,
         usaFiatAlterno: Bool = false,
         precioFiatAlterno: Decimal? = nil,
         valorTotalFiatAlterno: Decimal? = nil,
         cartera: Cartera,
         crypto: Crypto,
         fiatAlterno: FIAT? = nil) {
        self.id = UUID()
        self.fecha = fecha
        self.cantidadCrypto = cantidadCrypto
        self.precioUSD = precioUSD
        self.valorTotalUSD = cantidadCrypto * precioUSD
        self.usaFiatAlterno = usaFiatAlterno
        self.precioFiatAlterno = precioFiatAlterno
        self.valorTotalFiatAlterno = valorTotalFiatAlterno
        self.cartera = cartera
        self.crypto = crypto
        self.fiatAlterno = fiatAlterno
    }
}

// MARK: - Entidad MovimientoEgreso (DEPRECADA)
/// ⚠️ Deprecado: se conserva temporalmente solo para la migración v3 → v4
/// (`MovimientoMigration`). No usar en código nuevo — usar `Movimiento`.
@Model
class MovimientoEgreso {
    @Attribute(.unique) var id: UUID
    var fecha: Date

    // Campos principales en USD
    var cantidadCrypto: Decimal
    var precioUSD: Decimal
    var valorTotalUSD: Decimal

    // FIAT Alterno
    var usaFiatAlterno: Bool
    var precioFiatAlterno: Decimal?
    var valorTotalFiatAlterno: Decimal?

    // Relaciones
    @Relationship var cartera: Cartera?
    @Relationship var crypto: Crypto?
    @Relationship var fiatAlterno: FIAT?

    init(fecha: Date,
         cantidadCrypto: Decimal,
         precioUSD: Decimal,
         usaFiatAlterno: Bool = false,
         precioFiatAlterno: Decimal? = nil,
         valorTotalFiatAlterno: Decimal? = nil,
         cartera: Cartera,
         crypto: Crypto,
         fiatAlterno: FIAT? = nil) {
        self.id = UUID()
        self.fecha = fecha
        self.cantidadCrypto = cantidadCrypto
        self.precioUSD = precioUSD
        self.valorTotalUSD = cantidadCrypto * precioUSD
        self.usaFiatAlterno = usaFiatAlterno
        self.precioFiatAlterno = precioFiatAlterno
        self.valorTotalFiatAlterno = valorTotalFiatAlterno
        self.cartera = cartera
        self.crypto = crypto
        self.fiatAlterno = fiatAlterno
    }
}

// MARK: - Entidad MovimientoEntreCarteras (DEPRECADA)
/// ⚠️ Deprecado: se conserva temporalmente solo para la migración v3 → v4
/// (`MovimientoMigration`). No usar en código nuevo — usar `Movimiento`.
@Model
class MovimientoEntreCarteras {
    @Attribute(.unique) var id: UUID
    var fecha: Date
    var cantidadCryptoSalida: Decimal // Renombrado para claridad
    var cantidadCryptoEntrada: Decimal // Nuevo campo
    var cantidadCryptoComision: Decimal // Nuevo campo

    @Relationship var carteraOrigen: Cartera?
    @Relationship var carteraDestino: Cartera?
    @Relationship var crypto: Crypto?

    init(fecha: Date,
         cantidadCryptoSalida: Decimal,
         cantidadCryptoEntrada: Decimal,
         carteraOrigen: Cartera,
         carteraDestino: Cartera,
         crypto: Crypto) {
        self.id = UUID()
        self.fecha = fecha
        self.cantidadCryptoSalida = cantidadCryptoSalida
        self.cantidadCryptoEntrada = cantidadCryptoEntrada
        self.cantidadCryptoComision = cantidadCryptoSalida - cantidadCryptoEntrada
        self.carteraOrigen = carteraOrigen
        self.carteraDestino = carteraDestino
        self.crypto = crypto
    }
}

// MARK: - Entidad MovimientoSwap (DEPRECADA)
/// ⚠️ Deprecado: se conserva temporalmente solo para la migración v3 → v4
/// (`MovimientoMigration`). No usar en código nuevo — usar `Movimiento`.
@Model
class MovimientoSwap {
    @Attribute(.unique) var id: UUID
    var fecha: Date
    var cantidadOrigen: Decimal
    var cantidadDestino: Decimal
    var precioUSDOrigen: Decimal
    var precioUSDDestino: Decimal

    @Relationship var cartera: Cartera?
    @Relationship var cryptoOrigen: Crypto?
    @Relationship var cryptoDestino: Crypto?

    init(fecha: Date,
         cantidadOrigen: Decimal,
         cantidadDestino: Decimal,
         precioUSDOrigen: Decimal,
         precioUSDDestino: Decimal,
         cartera: Cartera,
         cryptoOrigen: Crypto,
         cryptoDestino: Crypto) {
        self.id = UUID()
        self.fecha = fecha
        self.cantidadOrigen = cantidadOrigen
        self.cantidadDestino = cantidadDestino
        self.precioUSDOrigen = precioUSDOrigen
        self.precioUSDDestino = precioUSDDestino
        self.cartera = cartera
        self.cryptoOrigen = cryptoOrigen
        self.cryptoDestino = cryptoDestino
    }
}
