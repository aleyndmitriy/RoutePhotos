//
//  SendMessageIdentity+CoreDataProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 25.01.2023.
//
//

import Foundation
import CoreData


extension SendMessageIdentity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SendMessageIdentity> {
        return NSFetchRequest<SendMessageIdentity>(entityName: "SendMessageIdentity")
    }

    @NSManaged public var sessionId: UUID?
    @NSManaged public var remoteType: Int16
    @NSManaged public var remoteDriveId: String?
    @NSManaged public var remoteAlbumIdentifier: String

}
