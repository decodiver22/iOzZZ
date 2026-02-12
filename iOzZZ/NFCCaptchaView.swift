//
//  NFCCaptchaView.swift
//  iOzZZ
//
//  NFC captcha UI - prompts user to scan the correct NFC tag to dismiss alarm.
//  Shows error feedback for wrong tags and tracks scan attempts.
//

import SwiftUI

struct NFCCaptchaView: View {
    let expectedTagID: String
    let onSolved: () -> Void

    @StateObject private var nfcService = NFCService()
    @State private var wrongTag = false
    @State private var attempts = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("Scan NFC Tag to Dismiss")
                    .font(.title2.bold())
            }

            // NFC icon
            Image(systemName: nfcService.isScanning ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                .font(.system(size: 80))
                .foregroundStyle(nfcService.isScanning ? .blue : .secondary)
                .symbolEffect(.pulse, isActive: nfcService.isScanning)

            // Status
            VStack(spacing: 8) {
                if nfcService.isScanning {
                    Text("Hold your phone near the registered NFC tag")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if wrongTag {
                    Text("Wrong tag! Scan the correct tag.")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                if let error = nfcService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if attempts > 0 {
                    Text("Attempts: \(attempts)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Scan button
            Button {
                startScan()
            } label: {
                Label(
                    nfcService.isScanning ? "Scanning..." : "Start NFC Scan",
                    systemImage: "wave.3.right"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal, 24)
            .disabled(nfcService.isScanning)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: wrongTag)
    }

    private func startScan() {
        wrongTag = false

        nfcService.scan { scannedID in
            if scannedID == expectedTagID {
                onSolved()
            } else {
                attempts += 1
                wrongTag = true

                Task {
                    try? await Task.sleep(for: .seconds(2))
                    wrongTag = false
                }
            }
        }
    }
}

#Preview {
    NFCCaptchaView(expectedTagID: "04:A2:3B:C1:D4:E5:F6", onSolved: {})
}
