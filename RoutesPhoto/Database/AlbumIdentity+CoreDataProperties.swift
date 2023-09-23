//
//  AlbumIdentity+CoreDataProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 25.01.2023.
//
//

import Foundation
import CoreData


extension AlbumIdentity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlbumIdentity> {
        return NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
    }

    @NSManaged public var localIdentifier: String
    @NSManaged public var localizedTitle: String
    @NSManaged public var order: Int32
    @NSManaged public var remoteDriveId: String?
    @NSManaged public var remoteFolderIdentifier: String?
    @NSManaged public var remoteFolderName: String?
    @NSManaged public var type: Int16
    @NSManaged public var photoIdentity: NSSet?
    @NSManaged public var messageIdentity: NSSet?

}

// MARK: Generated accessors for photoIdentity
extension AlbumIdentity {

    @objc(addPhotoIdentityObject:)
    @NSManaged public func addToPhotoIdentity(_ value: PhotoIdentity)

    @objc(removePhotoIdentityObject:)
    @NSManaged public func removeFromPhotoIdentity(_ value: PhotoIdentity)

    @objc(addPhotoIdentity:)
    @NSManaged public func addToPhotoIdentity(_ values: NSSet)

    @objc(removePhotoIdentity:)
    @NSManaged public func removeFromPhotoIdentity(_ values: NSSet)

}

// MARK: Generated accessors for messageIdentity
extension AlbumIdentity {

    @objc(addMessageIdentityObject:)
    @NSManaged public func addToMessageIdentity(_ value: MessageIdentity)

    @objc(removeMessageIdentityObject:)
    @NSManaged public func removeFromMessageIdentity(_ value: MessageIdentity)

    @objc(addMessageIdentity:)
    @NSManaged public func addToMessageIdentity(_ values: NSSet)

    @objc(removeMessageIdentity:)
    @NSManaged public func removeFromMessageIdentity(_ values: NSSet)

}

extension AlbumIdentity : Identifiable {

}
