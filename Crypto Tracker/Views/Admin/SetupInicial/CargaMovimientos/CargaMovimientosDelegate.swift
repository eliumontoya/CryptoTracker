import Foundation

protocol CargaMovimientosDelegate {
    func didUpdateProgress(_ message: String)
    func didCompleteTask(_ type: String, total: Int)
    func didEncounterError(_ error: Error)
}
