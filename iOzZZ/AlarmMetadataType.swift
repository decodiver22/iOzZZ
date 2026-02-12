//
//  AlarmMetadataType.swift
//  iOzZZ
//
//  AlarmKit metadata wrapper.
//  Passes the alarm UUID string to Live Activity intents so they know which alarm fired.
//  Must be nonisolated for Swift 6 concurrency compliance.
//

import AlarmKit

/// AlarmMetadata conformance required by AlarmKit.
/// We pass the alarm UUID string so the Live Activity intent can identify which alarm fired.
nonisolated
struct AlarmMetadataType: AlarmMetadata {
    var alarmIdentifier: String
}
