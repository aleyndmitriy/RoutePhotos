//
//  SentPhotosProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 26.09.2022.
//

import Foundation
import UIKit

class SentPhotosProperties: Identifiable, Hashable {
     var id: String
     var photoName: String
     var albumIdentifier: String
     var creationDate: Date
     var latitude: Double
     var longitude: Double
     var image: Data
     var remoteAlbumIdentifier: String
     var remoteDriveId: String?
     var remoteName: String?
     var remoteIdentifier: String?
     var remoteType: Int16
     var sessionId: UUID
    
    init(id: String, photoName: String, albumIdentifier: String, creationDate: Date, latitude: Double, longitude: Double, image: Data, remoteAlbumIdentifier: String, remoteType: Int16, sessionId: UUID) {
        self.id = id
        self.photoName = photoName
        self.albumIdentifier = albumIdentifier
        self.creationDate = creationDate
        self.latitude = latitude
        self.longitude = longitude
        self.image = image
        self.remoteAlbumIdentifier = remoteAlbumIdentifier
        self.remoteType = remoteType
        self.sessionId = sessionId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SentPhotosProperties, rhs: SentPhotosProperties) -> Bool {
        return lhs.id == rhs.id
    }
}
