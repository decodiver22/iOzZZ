import SwiftUI
import SwiftData

struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AlarmModel.hour), SortDescriptor(\AlarmModel.minute)])
    private var alarms: [AlarmModel]

    @State private var showingAddAlarm = false

    var body: some View {
        List {
            if alarms.isEmpty {
                ContentUnavailableView(
                    "No Alarms",
                    systemImage: "alarm",
                    description: Text("Tap + to create your first alarm")
                )
            }

            ForEach(alarms) { alarm in
                NavigationLink {
                    AlarmEditView(alarm: alarm)
                } label: {
                    AlarmRow(alarm: alarm)
                }
            }
            .onDelete(perform: deleteAlarms)
        }
        .navigationTitle("iOzZZ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddAlarm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            NavigationStack {
                AlarmEditView(alarm: nil)
            }
        }
    }

    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            // Cancel in AlarmKit before deleting from SwiftData
            try? AlarmService.shared.cancelAlarm(id: alarm.id)
            modelContext.delete(alarm)
        }
    }
}

// MARK: - Alarm Row

private struct AlarmRow: View {
    @Bindable var alarm: AlarmModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 8) {
                    Text(alarm.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(alarm.repeatDaysString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: alarm.captchaType == .math ? "function" : "wave.3.right")
                        .font(.caption2)
                    Text(alarm.captchaType.rawValue)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $alarm.isEnabled)
                .labelsHidden()
                .onChange(of: alarm.isEnabled) { _, newValue in
                    Task {
                        if newValue {
                            try? await AlarmService.shared.scheduleAlarm(alarm)
                        } else {
                            try? AlarmService.shared.cancelAlarm(id: alarm.id)
                        }
                    }
                }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AlarmListView()
    }
    .modelContainer(for: [AlarmModel.self, NFCTagModel.self], inMemory: true)
}
