import SwiftUI
import SwiftData

struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AlarmModel.hour), SortDescriptor(\AlarmModel.minute)])
    private var alarms: [AlarmModel]

    @State private var showingAddAlarm = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if alarms.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(alarms) { alarm in
                            NavigationLink {
                                AlarmEditView(alarm: alarm)
                            } label: {
                                AlarmRow(alarm: alarm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("iOzZZ")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddAlarm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            NavigationStack {
                AlarmEditView(alarm: nil)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.3))

            Text("No Alarms")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Tap + to create your first alarm")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(alarm.timeString)
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text(alarm.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))

                    Text(alarm.repeatDaysString)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                HStack(spacing: 6) {
                    Image(systemName: alarm.captchaType == .math ? "function" : "wave.3.right")
                        .font(.caption)
                    Text(alarm.captchaType.rawValue)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
                .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Toggle("", isOn: $alarm.isEnabled)
                .labelsHidden()
                .tint(.green)
                .scaleEffect(1.1)
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}

#Preview {
    NavigationStack {
        AlarmListView()
    }
    .modelContainer(for: [AlarmModel.self, NFCTagModel.self], inMemory: true)
}
