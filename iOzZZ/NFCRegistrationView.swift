import SwiftUI
import SwiftData

struct NFCRegistrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onTagRegistered: (String) -> Void

    @StateObject private var nfcService = NFCService()
    @State private var tagName = ""
    @State private var scannedTagID: String?

    var body: some View {
        Form {
            Section("Scan Tag") {
                if let tagID = scannedTagID {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Tag Scanned")
                                .font(.headline)
                            Text(tagID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Scan Again") {
                        scanTag()
                    }
                } else {
                    Button {
                        scanTag()
                    } label: {
                        Label(
                            nfcService.isScanning ? "Scanning..." : "Scan NFC Tag",
                            systemImage: "wave.3.right"
                        )
                    }
                    .disabled(nfcService.isScanning)
                }

                if let error = nfcService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if scannedTagID != nil {
                Section("Tag Name") {
                    TextField("e.g. Bedside lamp, Kitchen table", text: $tagName)
                }
            }
        }
        .navigationTitle("Register NFC Tag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveTag() }
                    .disabled(scannedTagID == nil || tagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func scanTag() {
        nfcService.scan { tagID in
            scannedTagID = tagID
        }
    }

    private func saveTag() {
        guard let tagID = scannedTagID else { return }

        let tag = NFCTagModel(
            tagIdentifier: tagID,
            name: tagName.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(tag)

        onTagRegistered(tagID)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NFCRegistrationView { _ in }
    }
    .modelContainer(for: NFCTagModel.self, inMemory: true)
}
