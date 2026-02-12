//
//  AlarmEditView.swift
//  iOzZZ
//
//  Alarm creation and editing form.
//  Configures time, repeat days, captcha type, snooze settings, and max snooze limits.
//  Includes delete button at bottom when editing existing alarms.
//

import SwiftUI
import SwiftData

struct AlarmEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // nil = creating a new alarm
    let alarm: AlarmModel?

    @State private var label: String = "Alarm"
    @State private var hour: Int = 8
    @State private var minute: Int = 0
    @State private var repeatDays: Set<Int> = []
    @State private var captchaType: CaptchaType = .math
    @State private var mathDifficulty: MathDifficulty = .easy
    @State private var nfcTagID: String?
    @State private var snoozeDurationMinutes: Int = 5
    @State private var maxSnoozes: Int = 3
    @State private var showingNFCRegistration = false
    @State private var errorMessage: String?

    @Query private var nfcTags: [NFCTagModel]

    private var isEditing: Bool { alarm != nil }
    private var selectedTime: Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }

    var body: some View {
        Form {
            // Time Picker
            Section {
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { selectedTime },
                        set: { newDate in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            hour = comps.hour ?? 8
                            minute = comps.minute ?? 0
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            // Label
            Section("Label") {
                TextField("Alarm name", text: $label)
            }

            // Repeat Days
            Section("Repeat") {
                RepeatDaysPicker(selectedDays: $repeatDays)
            }

            // Captcha Settings
            Section("Captcha Type") {
                Picker("Type", selection: $captchaType) {
                    ForEach(CaptchaType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if captchaType == .math {
                    Picker("Difficulty", selection: $mathDifficulty) {
                        ForEach(MathDifficulty.allCases, id: \.self) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                }

                if captchaType == .nfc {
                    if nfcTags.isEmpty {
                        Button("Register NFC Tag") {
                            showingNFCRegistration = true
                        }
                    } else {
                        Picker("NFC Tag", selection: $nfcTagID) {
                            Text("None").tag(nil as String?)
                            ForEach(nfcTags) { tag in
                                Text(tag.name).tag(tag.tagIdentifier as String?)
                            }
                        }

                        Button("Register New Tag") {
                            showingNFCRegistration = true
                        }
                    }
                }
            }

            // Snooze Settings
            Section {
                Picker("Duration", selection: $snoozeDurationMinutes) {
                    Text("1 min").tag(1)
                    Text("3 min").tag(3)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                }

                Picker("Max Snoozes", selection: $maxSnoozes) {
                    Text("Unlimited").tag(0)
                    Text("1 snooze").tag(1)
                    Text("2 snoozes").tag(2)
                    Text("3 snoozes").tag(3)
                    Text("5 snoozes").tag(5)
                    Text("10 snoozes").tag(10)
                }
            } header: {
                Text("Snooze")
            } footer: {
                if maxSnoozes > 0 {
                    Text("After \(maxSnoozes) snooze(s), you must solve the captcha to dismiss")
                } else {
                    Text("You can snooze unlimited times")
                }
            }

            // Error
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Alarm" : "New Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAlarm() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                Button(role: .destructive) {
                    deleteAlarm()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.headline)
                        Text("Delete Alarm")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showingNFCRegistration) {
            NavigationStack {
                NFCRegistrationView { tagID in
                    nfcTagID = tagID
                }
            }
        }
        .onAppear {
            if let alarm {
                label = alarm.label
                hour = alarm.hour
                minute = alarm.minute
                repeatDays = alarm.repeatDays
                captchaType = alarm.captchaType
                mathDifficulty = alarm.mathDifficulty
                nfcTagID = alarm.nfcTagID
                snoozeDurationMinutes = alarm.snoozeDurationMinutes
                maxSnoozes = alarm.maxSnoozes
            }
        }
    }

    private func saveAlarm() {
        if captchaType == .nfc && nfcTagID == nil {
            errorMessage = "Please register and select an NFC tag"
            return
        }

        if let alarm {
            // Update existing
            alarm.label = label
            alarm.hour = hour
            alarm.minute = minute
            alarm.repeatDays = repeatDays
            alarm.captchaType = captchaType
            alarm.mathDifficulty = mathDifficulty
            alarm.nfcTagID = nfcTagID
            alarm.snoozeDurationMinutes = snoozeDurationMinutes
            alarm.maxSnoozes = maxSnoozes

            if alarm.isEnabled {
                Task {
                    try? AlarmService.shared.cancelAlarm(id: alarm.id)
                    try? await AlarmService.shared.scheduleAlarm(alarm)
                }
            }
        } else {
            // Create new
            let newAlarm = AlarmModel(
                label: label,
                hour: hour,
                minute: minute,
                repeatDays: repeatDays,
                captchaType: captchaType,
                mathDifficulty: mathDifficulty,
                nfcTagID: nfcTagID,
                snoozeDurationMinutes: snoozeDurationMinutes,
                maxSnoozes: maxSnoozes
            )
            modelContext.insert(newAlarm)

            Task {
                try? await AlarmService.shared.scheduleAlarm(newAlarm)
            }
        }

        dismiss()
    }

    private func deleteAlarm() {
        guard let alarm = alarm else { return }

        // Cancel in AlarmKit
        try? AlarmService.shared.cancelAlarm(id: alarm.id)

        // Delete from SwiftData
        modelContext.delete(alarm)

        dismiss()
    }
}

// MARK: - Repeat Days Picker

private struct RepeatDaysPicker: View {
    @Binding var selectedDays: Set<Int>

    // Display Mon-Sun order (2,3,4,5,6,7,1)
    private let orderedDays = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(orderedDays, id: \.self) { day in
                DayButton(
                    day: day,
                    isSelected: selectedDays.contains(day),
                    onTap: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DayButton: View {
    let day: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(day.weekdaySymbol)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AlarmEditView(alarm: nil)
    }
    .modelContainer(for: [AlarmModel.self, NFCTagModel.self], inMemory: true)
}
