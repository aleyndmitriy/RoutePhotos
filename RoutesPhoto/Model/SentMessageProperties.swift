//
//  SentMessageProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 25.01.2023.
//

import Foundation

class SentMessageProperties: Identifiable, Hashable {
    var id: String
    var messageName: String
    var albumIdentifier: String
    var creationDate: Date
    var text: Data
    var remoteAlbumIdentifier: String
    var remoteDriveId: String?
    var remoteType: Int16
    var sessionId: UUID
    var remoteName: String?
    var remoteIdentifier: String?
    
    init(id: String, messageName: String, albumIdentifier: String, creationDate: Date, text: Data, remoteAlbumIdentifier: String, remoteType: Int16, sessionId: UUID) {
        self.id = id
        self.messageName = messageName
        self.albumIdentifier = albumIdentifier
        self.creationDate = creationDate
        self.text = text
        self.remoteAlbumIdentifier = remoteAlbumIdentifier
        self.remoteType = remoteType
        self.sessionId = sessionId
    }
    
    convenience init(copy:SentMessageProperties) {
        self.init(id: copy.id, messageName: copy.messageName, albumIdentifier: copy.albumIdentifier, creationDate: copy.creationDate, text: copy.text, remoteAlbumIdentifier: copy.remoteAlbumIdentifier, remoteType: copy.remoteType, sessionId: copy.sessionId)
        self.remoteName = copy.remoteName
        self.remoteIdentifier = copy.remoteIdentifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SentMessageProperties, rhs: SentMessageProperties) -> Bool {
        return lhs.id == rhs.id
    }
}
