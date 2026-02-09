import Foundation
import CoreNFC

final class NFCService: NSObject, ObservableObject {
    @Published var scannedTagID: String?
    @Published var errorMessage: String?
    @Published var isScanning = false

    private var session: NFCTagReaderSession?
    private var onScan: ((String) -> Void)?

    func scan(completion: @escaping (String) -> Void) {
        #if targetEnvironment(simulator)
        // Simulate a tag scan in the simulator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let mockID = "04:A2:3B:C1:D4:E5:F6"
            self.scannedTagID = mockID
            completion(mockID)
        }
        return
        #else
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }

        onScan = completion
        session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693],
            delegate: self,
            queue: nil
        )
        session?.alertMessage = "Hold your iPhone near the NFC tag"
        session?.begin()
        isScanning = true
        #endif
    }

    func stopScanning() {
        session?.invalidate()
        session = nil
        isScanning = false
    }

    /// Convert raw tag identifier bytes to hex string
    static func hexString(from data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension NFCService: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session started
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            if let nfcError = error as? NFCReaderError,
               nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }

        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            var identifier: Data?

            switch tag {
            case .miFare(let mifareTag):
                identifier = mifareTag.identifier
            case .iso15693(let iso15693Tag):
                identifier = iso15693Tag.identifier
            case .iso7816(let iso7816Tag):
                identifier = iso7816Tag.identifier
            case .feliCa(let feliCaTag):
                identifier = feliCaTag.currentIDm
            @unknown default:
                break
            }

            guard let id = identifier else {
                session.invalidate(errorMessage: "Could not read tag identifier")
                return
            }

            let hexID = NFCService.hexString(from: id)
            session.alertMessage = "Tag scanned successfully!"
            session.invalidate()

            DispatchQueue.main.async {
                self.scannedTagID = hexID
                self.isScanning = false
                self.onScan?(hexID)
                self.onScan = nil
            }
        }
    }
}
