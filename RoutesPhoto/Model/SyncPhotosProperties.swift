//
//  SyncPhotosProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 27.09.2022.
//

import Foundation
import UIKit

class SyncPhotosProperties: Identifiable, Hashable {
     let id: String
     let photoName: String
     let albumIdentifier: String
     let remoteId: String
     let remoteName: String
     let remoteAlbumIdentifier: String
     let sessionId: UUID
    
    init(id: String, photoName: String, albumIdentifier: String, remoteId: String, remoteName: String, remoteAlbumIdentifier: String, sessionId: UUID) {
        self.id = id
        self.photoName = photoName
        self.albumIdentifier = albumIdentifier
        self.remoteId = remoteId
        self.remoteName = remoteName
        self.remoteAlbumIdentifier = remoteAlbumIdentifier
        self.sessionId = sessionId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SyncPhotosProperties, rhs: SyncPhotosProperties) -> Bool {
        return lhs.id == rhs.id
    }
}

