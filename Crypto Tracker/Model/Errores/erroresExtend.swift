//
//  erroresExtend.swift
//  Crypto Tracker
//
//  Created by Eliu Montoya on 21/02/25.
//

 
enum ErrorInformacionFaltante2: Error {
    case montoInvalido
    case fechaInvalida
    case descripcionVacia
    case usoFiatInvalido
    
    var mensaje: String {
        switch self {
        case .montoInvalido:
            return "El monto debe ser mayor a 0."
        case .fechaInvalida:
            return "La fecha del movimiento no puede ser en el futuro."
        case .descripcionVacia:
            return "La descripción no puede estar vacía."
            
        case .usoFiatInvalido:
            return "La descripción no puede estar vacía."
            
        }
    }
}


 
// Error base para errores de negocio
class ErrorDeNegocio: Error {
    let nombre: String
    let descripcion: String
    
    init(nombre: String, descripcion: String) {
        self.nombre = nombre
        self.descripcion = descripcion
    }
    
    var localizedDescription: String {
        return "[\(nombre)] \(descripcion)"
    }
}

// Error específico para información faltante
class ErrorInformacionFaltante: ErrorDeNegocio {
    static let infoFaltante = ErrorInformacionFaltante(nombre: "infoFaltante", descripcion: "El monto, precio y el precio son obligatorios")
    static let fechaNoValida = ErrorInformacionFaltante(nombre: "FechaNoValida", descripcion: "La fecha ingresada no es válida.")
    static let fiatNoValido = ErrorInformacionFaltante(nombre: "FiatNoValido", descripcion: "La moneda FIAT seleccionada no es válida.")
    static let cryptoNoVacia = ErrorInformacionFaltante(nombre: "cryptoNoVacia", descripcion: "La crypto no puede estar vacia.")
    static let carteraNoVacia = ErrorInformacionFaltante(nombre: "carteraNoVacia", descripcion: "La cartera no puede estar vacia")

}
