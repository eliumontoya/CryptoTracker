
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
        Format.usd(carteraDetail.valorTotalUSD)
    }
    
    var gananciaTotal: String {
        Format.usd(carteraDetail.gananciaTotal)
    }
    
    var isGananciaPositive: Bool {
        carteraDetail.gananciaTotal >= 0
    }
    
    var rentabilidadFormatted: String {
        Format.percent(carteraDetail.rentabilidadTotal)
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
