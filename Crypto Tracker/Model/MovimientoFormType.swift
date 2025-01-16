enum MovimientoFormType: Identifiable {
    case entrada
    case salida
    case entreCarteras
    case swap
    
    var id: Self { self }  // Esto es más simple y funciona igual de bien
}
