//
//  NFCTagModel.swift
//  iOzZZ
//
//  SwiftData model for registered NFC tags.
//  Stores tag identifier (hex string from NFC UID) and user-assigned name.
//

import Foundation
import SwiftData

@Model
final class NFCTagModel {
    @Attribute(.unique) var id: UUID
    var tagIdentifier: String // hex string from NFC tag UID
    var name: String
    var registeredAt: Date

    init(
        id: UUID = UUID(),
        tagIdentifier: String,
        name: String,
        registeredAt: Date = .now
    ) {
        self.id = id
        self.tagIdentifier = tagIdentifier
        self.name = name
        self.registeredAt = registeredAt
    }
}
