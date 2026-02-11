import SwiftUI
import SwiftData

struct AlarmListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AlarmModel.hour), SortDescriptor(\AlarmModel.minute)])
    private var alarms: [AlarmModel]

    @State private var showingAddAlarm = false
    @State private var showingDebugMenu = false
    @State private var testCaptchaAlarmID: UUID?

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
                    LazyVStack(spacing: 24) {
                        ForEach(alarms) { alarm in
                            NavigationLink {
                                AlarmEditView(alarm: alarm)
                            } label: {
                                AlarmRow(alarm: alarm)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteAlarm(alarm)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("iOzZZ")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingDebugMenu = true
                } label: {
                    Image(systemName: "ant.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            #endif

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
        .fullScreenCover(isPresented: $showingDebugMenu) {
            DebugMenuView(
                onTestCaptcha: { alarmID in
                    testCaptchaAlarmID = alarmID
                },
                onClose: {
                    showingDebugMenu = false
                }
            )
        }
        .fullScreenCover(item: $testCaptchaAlarmID) { alarmID in
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .overlay {
                    CaptchaView(alarmID: alarmID) {
                        testCaptchaAlarmID = nil
                    }
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 120))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .white.opacity(0.1), radius: 20)

            VStack(spacing: 12) {
                Text("No Alarms")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Tap + to create your first alarm")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
    }

    private func deleteAlarm(_ alarm: AlarmModel) {
        // Cancel in AlarmKit before deleting from SwiftData
        try? AlarmService.shared.cancelAlarm(id: alarm.id)
        modelContext.delete(alarm)
    }
}

// MARK: - Alarm Row

private struct AlarmRow: View {
    @Bindable var alarm: AlarmModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top row: Time and Toggle
            HStack(alignment: .top) {
                Text(alarm.timeString)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Spacer()

                Toggle("", isOn: $alarm.isEnabled)
                    .labelsHidden()
                    .tint(.green)
                    .scaleEffect(1.3)
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

            // Label and repeat info
            HStack(spacing: 12) {
                Text(alarm.label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text("•")
                    .foregroundStyle(.white.opacity(0.5))

                Text(alarm.repeatDaysString)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
            }

            // Bottom row: Captcha badge and snooze info
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: alarm.captchaType == .math ? "function" : "wave.3.right")
                        .font(.callout.weight(.semibold))
                    Text(alarm.captchaType.rawValue)
                        .font(.callout.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        )
                )
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                if alarm.maxSnoozes > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.caption.weight(.semibold))
                        Text("\(alarm.maxSnoozes) max")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.15))
                    )
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(28)
        .background(
            ZStack {
                // Liquid glass effect with blur
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)

                // Inner glow
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Border highlight
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 15, y: 8)
        .shadow(color: .blue.opacity(0.2), radius: 20, y: 10)
    }
}

#Preview {
    NavigationStack {
        AlarmListView()
    }
    .modelContainer(for: [AlarmModel.self, NFCTagModel.self], inMemory: true)
}
