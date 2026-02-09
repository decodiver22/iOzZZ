import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            AlarmListView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AlarmModel.self, NFCTagModel.self], inMemory: true)
}
