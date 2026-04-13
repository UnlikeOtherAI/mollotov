import Foundation
import Network

/// Advertises the Kelpie service via mDNS using Network.framework.
final class MDNSAdvertiser: @unchecked Sendable {
    private var listener: NWListener?
    private let serviceType = "_kelpie._tcp"
    let txtRecord: [String: String]
    var onAdvertisingChange: ((Bool) -> Void)?
    private(set) var isRunning = false

    init(txtRecord: [String: String]) {
        self.txtRecord = txtRecord
    }

    func start() {
        stop()

        do {
            listener = try NWListener(using: .tcp)
        } catch {
            print("[mDNS] Failed to create listener: \(error)")
            onAdvertisingChange?(false)
            return
        }

        let txt = NWTXTRecord(txtRecord)
        listener?.service = NWListener.Service(
            name: txtRecord["name"] ?? "Kelpie",
            type: serviceType,
            txtRecord: txt
        )

        listener?.serviceRegistrationUpdateHandler = { change in
            switch change {
            case .add(let endpoint):
                print("[mDNS] Advertising: \(endpoint)")
            case .remove(let endpoint):
                print("[mDNS] Removed: \(endpoint)")
            @unknown default:
                break
            }
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.isRunning = true
                self.onAdvertisingChange?(true)
                print("[mDNS] Service advertised as \(self.serviceType)")
            case .failed(let error):
                self.isRunning = false
                self.onAdvertisingChange?(false)
                print("[mDNS] Advertisement failed: \(error)")
            case .cancelled:
                self.isRunning = false
                self.onAdvertisingChange?(false)
            default:
                break
            }
        }

        // We don't actually need to accept connections on this listener.
        // It exists solely for mDNS advertisement.
        listener?.newConnectionHandler = { connection in
            connection.cancel()
        }

        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        onAdvertisingChange?(false)
    }
}
