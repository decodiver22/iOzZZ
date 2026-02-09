import AlarmKit

/// Empty AlarmMetadata conformance required by AlarmKit.
/// We pass the alarm UUID string so the Live Activity intent can identify which alarm fired.
nonisolated
struct AlarmMetadataType: AlarmMetadata {
    var alarmIdentifier: String
}
