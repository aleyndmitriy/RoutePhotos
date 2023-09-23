//
//  SendPhotoIdentity+CoreDataProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 23.09.2022.
//
//

import Foundation
import CoreData


extension SendPhotoIdentity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SendPhotoIdentity> {
        return NSFetchRequest<SendPhotoIdentity>(entityName: "SendPhotoIdentity")
    }

    @NSManaged public var albumIdentifier: String
    @NSManaged public var creationDate: Date
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var image: Data
    @NSManaged public var photoIdentifier: String
    @NSManaged public var photoName: String
    @NSManaged public var remoteIdentifier: String?
    @NSManaged public var remoteName: String?
    @NSManaged public var remoteAlbumIdentifier: String
    @NSManaged public var remoteDriveId: String?
    @NSManaged public var remoteType: Int16
    @NSManaged public var sessionId: UUID?

}

extension SendPhotoIdentity : Identifiable {

}
