
// CarteraCryptoDetailViewModel.swift
import Foundation
import SwiftData
import Combine
// Añadir al archivo anterior

// CarteraDetailViewModel.swift
@MainActor
final class CarteraDetailViewModel: ObservableObject {
    @Published var selectedCryptoDetail: (Crypto, Cartera)?
    @Published var showingCarteraMovimientos = false
    @Published var showingEntradaForm = false
    @Published var showingSalidaForm = false
    @Published var showingEntreCarterasForm = false
    @Published var showingSwapForm = false
    
    let carteraDetail: CarteraDetail
    let onUpdateData: () -> Void
    
    init(carteraDetail: CarteraDetail, onUpdateData: @escaping () -> Void) {
        self.carteraDetail = carteraDetail
        self.onUpdateData = onUpdateData
    }
    
    // MARK: - Computed Properties
    var carteraNombre: String {
        carteraDetail.cartera.nombre
    }
    
    var valorTotalUSD: String {
        carteraDetail.valorTotalUSD.formatted(.currency(code: "USD"))
    }
    
    var gananciaTotal: String {
        carteraDetail.gananciaTotal.formatted(.currency(code: "USD"))
    }
    
    var isGananciaPositive: Bool {
        carteraDetail.gananciaTotal >= 0
    }
    
    var rentabilidadFormatted: String {
        carteraDetail.rentabilidadTotal.formatted(.number.precision(.fractionLength(2))) + "%"
    }
    
    var cryptoDetails: [CryptoDetail] {
        carteraDetail.cryptoDetails
    }
    
    // MARK: - Actions
    func onCryptoSelected(_ detail: CryptoDetail) {
        selectedCryptoDetail = (detail.crypto, carteraDetail.cartera)
    }
    
    func updateData() {
        onUpdateData()
    }
}
