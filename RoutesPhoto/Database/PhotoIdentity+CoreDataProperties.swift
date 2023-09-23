//
//  PhotoIdentity+CoreDataProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 23.09.2022.
//
//

import Foundation
import CoreData


extension PhotoIdentity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PhotoIdentity> {
        return NSFetchRequest<PhotoIdentity>(entityName: "PhotoIdentity")
    }

    @NSManaged public var albumIdentifier: String
    @NSManaged public var creationDate: Date
    @NSManaged public var latitude: Double
    @NSManaged public var locked: Bool
    @NSManaged public var longitude: Double
    @NSManaged public var image: Data
    @NSManaged public var photoIdentifier: String
    @NSManaged public var photoName: String
    @NSManaged public var remoteIdentifier: String?
    @NSManaged public var remoteName: String?
    @NSManaged public var locationAddress: String?
    @NSManaged public var album: AlbumIdentity?

}

extension PhotoIdentity : Identifiable {

}
