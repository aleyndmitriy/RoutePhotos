//
//  MessageIdentity+CoreDataProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 25.01.2023.
//
//

import Foundation
import CoreData


extension MessageIdentity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageIdentity> {
        return NSFetchRequest<MessageIdentity>(entityName: "MessageIdentity")
    }

    @NSManaged public var remoteName: String?
    @NSManaged public var remoteIdentifier: String?
    @NSManaged public var photoIdentifier: String
    @NSManaged public var messageName: String
    @NSManaged public var messageIdentifier: String
    @NSManaged public var locked: Bool
    @NSManaged public var creationDate: Date
    @NSManaged public var text: Data
    @NSManaged public var albumIdentifier: String
    @NSManaged public var relalbum: AlbumIdentity?

}

extension MessageIdentity : Identifiable {

}
