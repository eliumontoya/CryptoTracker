import Foundation
import SwiftData

// MARK: - Extensiones de validación
extension String {
    func validated(maxLength: Int) -> String {
        String(self.prefix(maxLength))
    }
}

// MARK: - Enums
enum TipoMovimiento {
    case ingreso
    case egreso
    case entreCarteras
    case swap
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
    
    @Relationship(inverse: \MovimientoIngreso.fiatAlterno) var movimientosIngreso: [MovimientoIngreso] = []
    @Relationship(inverse: \MovimientoEgreso.fiatAlterno) var movimientosEgreso: [MovimientoEgreso] = []
    
    init(nombre: String, simbolo: String, precioUSD: Decimal) {
        self.id = UUID()
        self.nombre = nombre.validated(maxLength: 20)
        self.simbolo = simbolo.validated(maxLength: 10)
        self.precioUSD = precioUSD
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
    
    @Relationship(inverse: \MovimientoIngreso.cartera) var movimientosIngreso: [MovimientoIngreso] = []
    @Relationship(inverse: \MovimientoEgreso.cartera) var movimientosEgreso: [MovimientoEgreso] = []
    @Relationship(inverse: \MovimientoEntreCarteras.carteraOrigen) var movimientosSalida: [MovimientoEntreCarteras] = []
    @Relationship(inverse: \MovimientoEntreCarteras.carteraDestino) var movimientosEntrada: [MovimientoEntreCarteras] = []
    @Relationship(inverse: \MovimientoSwap.cartera) var swaps: [MovimientoSwap] = []
    
    init(nombre: String, simbolo: String) {
        self.id = UUID()
        self.nombre = nombre.validated(maxLength: 20)
        self.simbolo = simbolo.validated(maxLength: 10)
        self.movimientosIngreso = []
        self.movimientosEgreso = []
        self.movimientosSalida = []
        self.movimientosEntrada = []
        self.swaps = []
    }
}

// MARK: - Entidad MovimientoIngreso
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

// MARK: - Entidad MovimientoEgreso
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

// MARK: - Entidad MovimientoEntreCarteras
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

// MARK: - Entidad MovimientoSwap
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
