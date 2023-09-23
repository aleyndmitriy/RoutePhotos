//
//  CoreDataSyncAssetDatabase.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 08.09.2022.
//

import UIKit
import CoreData

class CoreDataSyncAssetDatabase: NSObject {
    private let dataModelName: String = "SyncAssetIdentityDatabase"
    private let dataBaseName: String = "SyncAssetIdentityDatabase.sql"
    static let shared = CoreDataSyncAssetDatabase()
    var persistentStoreCoordinator: NSPersistentStoreCoordinator
    var context: NSManagedObjectContext
    
    private override init() {
        guard let modelURL = Bundle.main.url(forResource: dataModelName,
                                             withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        guard let momd = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create model from file: \(modelURL)")
        }
        let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
        let fileURL = URL(string: dataBaseName, relativeTo: dirURL)
        
        print("path to base:\(String(describing: fileURL))")
        self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: momd)
        do {
            try self.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                       configurationName: nil,
                                       at: fileURL, options: nil)
        } catch {
            fatalError("Error configuring persistent store: \(error)")
        }
        
        self.context = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        self.context.persistentStoreCoordinator = self.persistentStoreCoordinator
        self.context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.context.undoManager = nil
        super.init()
    }
    
    private func newBackgroundTaskContext() -> NSManagedObjectContext {
        let taskContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        taskContext.undoManager = nil
        taskContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        return taskContext
    }
    
    
    func insertIdentityItem(folderItem: FolderItem) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "savingContext"
        taskContext.transactionAuthor = "savingFolder"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: folderItem.localName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            request.predicate = predicate
            do {
                if let album: AlbumIdentity = try taskContext.fetch(request).first {
                    print("folder with name \(album.localizedTitle) already exist.")
                    throw PhotoError.creationError
                }
            } catch {
                throw PhotoError.creationError
            }
            let album: AlbumIdentity = AlbumIdentity(context: taskContext)
            album.localIdentifier = folderItem.id
            album.localizedTitle = folderItem.localName
            if folderItem.remoteId.isEmpty == false {
                album.remoteFolderIdentifier = folderItem.remoteId
            } else {
                album.remoteFolderIdentifier = nil
            }
            if folderItem.remoteName.isEmpty == false {
                album.remoteFolderName = folderItem.remoteName
            } else {
                album.remoteFolderName = nil
            }
            if folderItem.remoteDriveId.isEmpty == false {
                album.remoteDriveId = folderItem.remoteDriveId
            } else {
                album.remoteDriveId = nil
            }
            album.type = folderItem.folderSource.rawValue
            album.order = folderItem.order
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.creationError
            }
        }
    }
    
    
    func insertMessage(localId: String, localName: String, messages: [MessageProperties]) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "savingMessage"
        taskContext.transactionAuthor = "savingPhotoMessage"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: localName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first else {
                        print("folder with name \(localName) does not exist.")
                        throw PhotoError.missingData
                    }
                let messageSet = NSMutableSet()
                for messageItem: MessageProperties in messages {
                    let item: MessageIdentity = MessageIdentity(context: taskContext)
                    item.messageIdentifier = messageItem.id.uuidString
                    item.text = Data(messageItem.text.utf8)
                    item.messageName = messageItem.name
                    item.photoIdentifier = messageItem.photoId
                    item.creationDate = messageItem.date
                    item.locked = false
                    item.albumIdentifier = album.localIdentifier
                    messageSet.add(item)
                }
                album.addToMessageIdentity(messageSet)
            } catch {
                throw PhotoError.creationError
            }
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.creationError
            }
        }
    }
    
    func insertPhoto(localId: String, localName: String, photos: [PhotosProperties]) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "savingContext"
        taskContext.transactionAuthor = "savingFolder"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: localName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first else {
                        print("folder with name \(localName) does not exist.")
                        throw PhotoError.missingData
                    }
                let photoSet = NSMutableSet()
                for photoItem: PhotosProperties in photos {
                    let item: PhotoIdentity = PhotoIdentity(context: taskContext)
                    item.image = photoItem.image
                    item.photoIdentifier = photoItem.id.uuidString
                    item.photoName = photoItem.name
                    item.latitude = photoItem.latitude
                    item.longitude = photoItem.longitude
                    item.locationAddress = photoItem.address
                    item.creationDate = photoItem.date
                    item.locked = false
                    item.albumIdentifier = album.localIdentifier
                    photoSet.add(item)
                }
                album.addToPhotoIdentity(photoSet)
            } catch {
                throw PhotoError.creationError
            }
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.creationError
            }
        }
    }

    func loadMessages(localId: String, localName: String, photoId: UUID) async throws -> [MessageProperties] {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "loadingContextMessage"
        taskContext.transactionAuthor = "loadingFoldersMessages"
        var messageProperties = [MessageProperties]()
        let result: [AlbumIdentity] = try await taskContext.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: localName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                return try taskContext.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        if let album: AlbumIdentity = result.first, let messageIdentities: NSSet = album.messageIdentity, messageIdentities.count > 0 {
            for messageItem: Any in messageIdentities {
                guard let message: MessageIdentity = messageItem as? MessageIdentity, let messageId: UUID = UUID(uuidString: message.messageIdentifier), let parentPhotoId: UUID = UUID(uuidString: message.photoIdentifier)  else {
                    print("Can't load data from core base.")
                    throw PhotoError.creationError
                }
                var status: PhotoStatus = .local
                if message.locked {
                    status = .pending
                    if let _: String = message.remoteIdentifier, let _: String = message.remoteName {
                        status = .synchronized
                    }
                }
                if parentPhotoId == photoId {
                    let str = String(decoding: message.text, as: UTF8.self)
                    let finalMessage: MessageProperties = MessageProperties(id: messageId, photoId: message.photoIdentifier, name: message.messageName, text: str, date: message.creationDate, status: status)
                    messageProperties.append(finalMessage)
                }
            }
        }
        let res:[MessageProperties] = messageProperties.sorted { (item1: MessageProperties, item2: MessageProperties) in
            return item1.date < item2.date
        }
        return res
    }
    
    func loadPhoto(localId: String, localName: String) async throws -> [PhotosProperties] {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "loadingContext"
        taskContext.transactionAuthor = "loadingFolder"
        var photosProperties = [PhotosProperties]()
        let result: [AlbumIdentity] = try await taskContext.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: localName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                return try taskContext.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        if let album: AlbumIdentity = result.first, let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 {
            for photoIdentity: Any in photoIdentities {
                guard let photo: PhotoIdentity = photoIdentity as? PhotoIdentity, let photoId: UUID = UUID(uuidString: photo.photoIdentifier)  else {
                    print("Can't load data from core base.")
                    throw PhotoError.creationError
                }
                var status: PhotoStatus = .local
                if photo.locked {
                    status = .pending
                    if let _: String = photo.remoteIdentifier, let _: String = photo.remoteName {
                        status = .synchronized
                    }
                }
                var address: String = String()
                if let photoAddress: String = photo.locationAddress {
                    address = photoAddress
                }
                let property: PhotosProperties = PhotosProperties(id: photoId, name: photo.photoName,image: photo.image, date: photo.creationDate, longitude: photo.longitude, latitude: photo.latitude, address: address, status: status)
                photosProperties.append(property)
            }
        }
        let res:[PhotosProperties] = photosProperties.sorted { (item1: PhotosProperties, item2: PhotosProperties) in
            return item1.date < item2.date
        }
        return res
    }
    
    func deleteAlbumIdentity(localId: String, localName: String) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "deletingContext"
        taskContext.transactionAuthor = "deletingFolder"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            request.includesPropertyValues = false
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr2 = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr2 = NSExpression(forConstantValue: localName)
            let seconfPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, seconfPredicate])
            request.predicate = compoundPredicate
            let objects = try taskContext.fetch(request)
            for object in objects {
                taskContext.delete(object)
            }
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.deleteError
            }
        }
    }
    
    func updateAlbumIdentity(localId: String, albumName: String, newName: String, storageType: FolderSource, newRemoteId: String, newRemoteName: String, newRemoteDriveId: String) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updatingNameContext"
        taskContext.transactionAuthor = "updatingNameFolder"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr2 = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr2 = NSExpression(forConstantValue: albumName)
            let seconfPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, seconfPredicate])
            request.predicate = compoundPredicate
            let objects = try taskContext.fetch(request)
            guard let album: AlbumIdentity = objects.first else {
                throw PhotoError.updateError
            }
           
            album.localizedTitle = newName
            
            if newRemoteId.isEmpty {
                album.remoteFolderIdentifier = nil
            } else {
                album.remoteFolderIdentifier = newRemoteId
            }
            
            if newRemoteName.isEmpty {
                album.remoteFolderName = nil
            } else {
                album.remoteFolderName = newRemoteName
            }
            
            if newRemoteDriveId.isEmpty {
                album.remoteDriveId = nil
            } else {
                album.remoteDriveId = newRemoteDriveId
            }
            
            album.type = storageType.rawValue
            
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.updateError
            }
        }
    }
    
    func updateAlbumIdentity(localId: String, albumName: String, newName: String) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updatingNameContext"
        taskContext.transactionAuthor = "updatingNameFolder"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr2 = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr2 = NSExpression(forConstantValue: albumName)
            let seconfPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, seconfPredicate])
            request.predicate = compoundPredicate
            let objects = try taskContext.fetch(request)
            guard let album: AlbumIdentity = objects.first else {
                throw PhotoError.updateError
            }
            album.localizedTitle = newName
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.updateError
            }
        }
    }
    
    func updateAlbumIdentity(localId: String, albumName: String, storageType: FolderSource, newRemoteId: String, newRemoteName: String, newRemoteDriveId: String) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updatingNameContext"
        taskContext.transactionAuthor = "updatingNameFolder"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr2 = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr2 = NSExpression(forConstantValue: albumName)
            let seconfPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, seconfPredicate])
            request.predicate = compoundPredicate
            let objects = try taskContext.fetch(request)
            guard let album: AlbumIdentity = objects.first else {
                throw PhotoError.updateError
            }
            
            if newRemoteId.isEmpty  {
                album.remoteFolderIdentifier = nil
                
            } else {
                album.remoteFolderIdentifier = newRemoteId
            }
            if newRemoteName.isEmpty {
                album.remoteFolderName = nil
            } else {
                album.remoteFolderName = newRemoteName
                
            }
            if newRemoteDriveId.isEmpty {
                album.remoteDriveId = nil
            } else {
                album.remoteDriveId = newRemoteDriveId
            }
            album.type = storageType.rawValue
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.updateError
            }
        }
    }
    func updatePhotoName(localId: String, albumName: String, photosId: UUID, newName: String) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updateContext"
        taskContext.transactionAuthor = "updatePhoto"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: albumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first, let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 else {
                        print("folder with name \(albumName) does not exist.")
                        throw PhotoError.missingData
                    }
                if let messageIdentities: NSSet = album.messageIdentity, messageIdentities.count > 0 {
                    for mesIdentity: Any in messageIdentities {
                        guard let message: MessageIdentity = mesIdentity as? MessageIdentity, let _: UUID = UUID(uuidString: message.messageIdentifier), let msgPhotoId: UUID = UUID(uuidString:message.photoIdentifier)  else {
                            print("Can't load data from core base.")
                            throw PhotoError.missingData
                        }
                        if msgPhotoId == photosId {
                            message.locked = false
                            message.remoteName = nil
                            message.messageName = newName
                        }
                    }
                }
                for photoIdentity: Any in photoIdentities {
                    guard let photo: PhotoIdentity = photoIdentity as? PhotoIdentity, let photoId: UUID = UUID(uuidString: photo.photoIdentifier)  else {
                        print("Can't load data from core base.")
                        throw PhotoError.missingData
                    }
                    if photoId == photosId{
                        photo.photoName = newName
                        photo.locked = false
                        photo.remoteName = nil
                        try taskContext.save()
                        return
                    }
                }
            } catch {
                throw PhotoError.updateError
            }
        }
    }
    
    func updateMessage(localId: String, albumName: String, newMessage: MessageProperties) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updateContext"
        taskContext.transactionAuthor = "updatePhoto"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: albumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first, let messageIdentities: NSSet = album.messageIdentity, messageIdentities.count > 0 else {
                        print("message in folder with name \(albumName) does not exist.")
                        throw PhotoError.missingData
                    }
                for mesIdentity: Any in messageIdentities {
                    guard let message: MessageIdentity = mesIdentity as? MessageIdentity, let mesId: UUID = UUID(uuidString: message.messageIdentifier)  else {
                        print("Can't load data from core base.")
                        throw PhotoError.missingData
                    }
                    if mesId == newMessage.id {
                        message.messageName = newMessage.name
                        message.text = Data(newMessage.text.utf8)
                        message.creationDate = newMessage.date
                        message.locked = false
                        message.remoteName = nil
                        try taskContext.save()
                        return
                    }
                }
            } catch {
                throw PhotoError.updateError
            }
        }
    }
    
    func updatePhotoAddress(localId: String, albumName: String, photosId: UUID, address: String) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updateContext"
        taskContext.transactionAuthor = "updatePhoto"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: albumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first, let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 else {
                        print("folder with name \(albumName) does not exist.")
                        throw PhotoError.missingData
                    }
                for photoIdentity: Any in photoIdentities {
                    guard let photo: PhotoIdentity = photoIdentity as? PhotoIdentity, let photoId: UUID = UUID(uuidString: photo.photoIdentifier)  else {
                        print("Can't load data from core base.")
                        throw PhotoError.missingData
                    }
                    if photoId == photosId{
                        photo.locationAddress = address
                        try taskContext.save()
                        return
                    }
                }
            } catch {
                throw PhotoError.updateError
            }
        }
    }
    
    func deletePhoto(localId: String, albumName: String, photoPropertyId: UUID) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "deletingContext"
        taskContext.transactionAuthor = "deletingPhoto"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: albumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first, let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 else {
                        print("folder with name \(albumName) does not exist.")
                        throw PhotoError.missingData
                    }
                for photoIdentity: Any in photoIdentities {
                    guard let photo: PhotoIdentity = photoIdentity as? PhotoIdentity, let photoId: UUID = UUID(uuidString: photo.photoIdentifier)  else {
                        print("Can't load data from core base.")
                        throw PhotoError.missingData
                    }
                    if photoId == photoPropertyId {
                        album.removeFromPhotoIdentity(photo)
                        if let messageIdentities: NSSet = album.messageIdentity, messageIdentities.count > 0 {
                            for messageIdentity: Any in messageIdentities {
                                guard let message: MessageIdentity = messageIdentity as? MessageIdentity, let messagePhotoId: UUID = UUID(uuidString: message.photoIdentifier)  else {
                                    print("Can't load data from core base.")
                                    throw PhotoError.missingData
                                }
                                if photoId == messagePhotoId {
                                    album.removeFromMessageIdentity(message)
                                }
                            }
                        }
                        try taskContext.save()
                        return
                    }
                }
            } catch {
                throw PhotoError.deleteError
            }
        }
    }
    
    func deleteMessage(localId: String, albumName: String, messageId: UUID) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "deletingContextMessage"
        taskContext.transactionAuthor = "deletingMessage"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: albumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first, let messageIdentities: NSSet = album.messageIdentity, messageIdentities.count > 0 else {
                        print("message in folder with name \(albumName) does not exist.")
                        throw PhotoError.missingData
                    }
                for messageIdent: Any in messageIdentities {
                    guard let message: MessageIdentity = messageIdent as? MessageIdentity, let mesId: UUID = UUID(uuidString: message.messageIdentifier)  else {
                        print("Can't load data from core base.")
                        throw PhotoError.missingData
                    }
                    if mesId == messageId {
                        album.removeFromMessageIdentity(message)
                        try taskContext.save()
                        return
                    }
                }
            } catch {
                throw PhotoError.deleteError
            }
        }
    }
    
    func deletePhotos(localId: String, albumName: String, photoPropertiesIDs: [UUID]) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "deletingContext"
        taskContext.transactionAuthor = "deletingPhoto"
        try await taskContext.perform {
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: localId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: albumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                guard let album: AlbumIdentity = try taskContext.fetch(request).first, let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 else {
                        print("photo in folder with name \(albumName) does not exist.")
                        throw PhotoError.missingData
                    }
                
                let removingPhotos: NSMutableSet = NSMutableSet()
                for photoIdentity: Any in photoIdentities {
                    guard let photo: PhotoIdentity = photoIdentity as? PhotoIdentity, let photoId: UUID = UUID(uuidString: photo.photoIdentifier)  else {
                        print("Can't load data from core base.")
                        throw PhotoError.missingData
                    }
                    if let _: UUID = photoPropertiesIDs.first(where: { (propertyId:UUID )in
                        return propertyId == photoId
                    }) {
                        removingPhotos.add(photo)
                    }
                    if let messageIdentities: NSSet = album.messageIdentity, messageIdentities.count > 0 {
                        for messageIdentity: Any in messageIdentities {
                            guard let message: MessageIdentity = messageIdentity as? MessageIdentity, let messagePhotoId: UUID = UUID(uuidString: message.photoIdentifier)  else {
                                print("Can't load data from core base.")
                                throw PhotoError.missingData
                            }
                            if photoId == messagePhotoId {
                                album.removeFromMessageIdentity(message)
                            }
                        }
                    }
                }
                if removingPhotos.count > 0 {
                    album.removeFromPhotoIdentity(removingPhotos)
                    try taskContext.save()
                }
            } catch {
                throw PhotoError.deleteError
            }
        }
    }
    
    func getIdentitiesItems() async throws -> [AlbumIdentity] {
        let result: [AlbumIdentity] = try await self.context.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \AlbumIdentity.order, ascending: true), NSSortDescriptor(keyPath: \AlbumIdentity.localizedTitle, ascending: true)]
            do {
                return try self.context.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        return result
    }
    
    func getIdentitiesItems(albumName: String) async throws -> [AlbumIdentity] {
        let result: [AlbumIdentity] = try await self.context.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: albumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            request.predicate = predicate
            do {
                return try self.context.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        return result
    }
    
    func getIdentitiesItems(albumId: String) async throws -> [AlbumIdentity] {
        let result: [AlbumIdentity] = try await self.context.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr = NSExpression(forKeyPath: "localIdentifier")
            let secondExpr = NSExpression(forConstantValue: albumId)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            request.predicate = predicate
            do {
                return try self.context.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        return result
    }
    
    func checkDublicates(albumName: String) async throws  {
        do {
            let result: [AlbumIdentity] = try await self.context.perform({
                let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
                let firstExpr = NSExpression(forKeyPath: "localizedTitle")
                let secondExpr = NSExpression(forConstantValue: albumName)
                let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
                request.predicate = predicate
                request.includesPropertyValues = false
                do {
                    return try self.context.fetch(request)
                } catch {
                    throw PhotoError.unexpectedError(error: error)
                }
            })
            if let _: AlbumIdentity = result.first {
                throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Folder with name \(albumName) already exist."])
            }
        } catch {
            throw error
        }
    }
    
    func getIdentitiesItems(remoteId: String, remoteName: String) async throws -> [AlbumIdentity] {
        let result: [AlbumIdentity] = try await self.context.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "remoteFolderIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: remoteId)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr2 = NSExpression(forKeyPath: "remoteFolderName")
            let secondExpr2 = NSExpression(forConstantValue: remoteName)
            let seconfPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, seconfPredicate])
            request.predicate = compoundPredicate
            do {
                return try self.context.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        return result
    }
    
    func checkDublicates(remoteId: String, remoteName: String) async throws {
        do {
            let result: [AlbumIdentity] = try await self.context.perform({
                let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
                let firstExpr1 = NSExpression(forKeyPath: "remoteFolderIdentifier")
                let secondExpr1 = NSExpression(forConstantValue: remoteId)
                let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
                let firstExpr2 = NSExpression(forKeyPath: "remoteFolderName")
                let secondExpr2 = NSExpression(forConstantValue: remoteName)
                let seconfPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
                let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, seconfPredicate])
                request.predicate = compoundPredicate
                request.includesPropertyValues = false
                do {
                    return try self.context.fetch(request)
                } catch {
                    throw PhotoError.unexpectedError(error: error)
                }
            })
            if let _: AlbumIdentity = result.first {
                throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Folder with name \(remoteName) already exist."])
            }
        } catch {
            throw error
        }
    }
    
    func checkDublicates(remoteName: String) async throws {
        do {
            let result: [AlbumIdentity] = try await self.context.perform({
                let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
                let firstExpr = NSExpression(forKeyPath: "remoteFolderName")
                let secondExpr = NSExpression(forConstantValue: remoteName)
                let redicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
                request.predicate = redicate
                request.includesPropertyValues = false
                do {
                    return try self.context.fetch(request)
                } catch {
                    throw PhotoError.unexpectedError(error: error)
                }
            })
            if let _: AlbumIdentity = result.first {
                throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Folder with name \(remoteName) already exist."])
            }
        } catch {
            throw error
        }
    }
    
    func enqueuePhotos(folderType: FolderSource) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "loadingContext"
        taskContext.transactionAuthor = "loadingFolder"
        let result: [AlbumIdentity] = try await taskContext.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "remoteFolderIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: nil)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.notEqualTo)
            let firstExpr2 = NSExpression(forKeyPath: "remoteFolderName")
            let secondExpr2 = NSExpression(forConstantValue: nil)
            let secondPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.notEqualTo)
            let firstExpr3 = NSExpression(forKeyPath: "type")
            let secondExpr3 = NSExpression(forConstantValue:folderType.rawValue)
            let thirdPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr3, rightExpression: secondExpr3, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, secondPredicate, thirdPredicate])
            request.predicate = compoundPredicate
            do {
                return try taskContext.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        for album: AlbumIdentity in result {
            if let remoteId: String = album.remoteFolderIdentifier, let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 {
                for photoIdentity: Any in photoIdentities {
                    guard let photo: PhotoIdentity = photoIdentity as? PhotoIdentity else {
                        print("Can't load data from core base.")
                        throw PhotoError.creationError
                    }
                    if photo.locked == false {
                        let sendIdentity: SendPhotoIdentity = SendPhotoIdentity(context: taskContext)
                        sendIdentity.remoteAlbumIdentifier = remoteId
                        sendIdentity.albumIdentifier = album.localIdentifier
                        sendIdentity.remoteDriveId = album.remoteDriveId
                        sendIdentity.image = photo.image
                        sendIdentity.creationDate = photo.creationDate
                        sendIdentity.photoIdentifier = photo.photoIdentifier
                        sendIdentity.photoName = photo.photoName
                        sendIdentity.latitude = photo.latitude
                        sendIdentity.remoteIdentifier = photo.remoteIdentifier
                        sendIdentity.remoteName = photo.remoteName
                        sendIdentity.longitude = photo.longitude
                        sendIdentity.remoteType = album.type
                        photo.locked = true
                    }
                }
            }
        }
        if taskContext.hasChanges {
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.creationError
            }
        }
    }
    
    
    func enqueueMessage(folderType: FolderSource) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "loadingContext"
        taskContext.transactionAuthor = "loadingFolderMessage"
        let result: [AlbumIdentity] = try await taskContext.perform({
            let request = NSFetchRequest<AlbumIdentity>(entityName: "AlbumIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "remoteFolderIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: nil)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.notEqualTo)
            let firstExpr = NSExpression(forKeyPath: "remoteFolderName")
            let secondExpr = NSExpression(forConstantValue: nil)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.notEqualTo)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                return try taskContext.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        for album: AlbumIdentity in result {
            if let remoteId: String = album.remoteFolderIdentifier, album.type == folderType.rawValue, let messageIdentities: NSSet = album.messageIdentity, messageIdentities.count > 0 , let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 {
                var photosProperties: [PhotoIdentityItem] = [PhotoIdentityItem]()
                for photoIdentity: Any in photoIdentities {
                    guard let photo: PhotoIdentity = photoIdentity as? PhotoIdentity, let _: UUID = UUID(uuidString: photo.photoIdentifier)  else {
                        print("Can't load data from core base.")
                        throw PhotoError.creationError
                    }
                    if let remoteId: String = photo.remoteIdentifier, let remoteName: String = photo.remoteName {
                        let property: PhotoIdentityItem = PhotoIdentityItem(id: photo.photoIdentifier, albumIdentifier: photo.albumIdentifier, photoName: photo.photoName, remoteIdentifier: remoteId, remoteName: remoteName)
                        photosProperties.append(property)
                    }
                }
                for mesIdentity: Any in messageIdentities {
                    guard let message: MessageIdentity = mesIdentity as? MessageIdentity else {
                        print("Can't load data from core base.")
                        throw PhotoError.creationError
                    }
                    if let photo: PhotoIdentityItem = photosProperties.last(where: { (item:PhotoIdentityItem) in
                        return item.id == message.photoIdentifier
                    }), message.locked == false {
                        let sendIdentity: SendMessageIdentity = SendMessageIdentity(context: taskContext)
                        sendIdentity.remoteAlbumIdentifier = remoteId
                        sendIdentity.albumIdentifier = album.localIdentifier
                        sendIdentity.remoteDriveId = album.remoteDriveId
                        sendIdentity.text = message.text
                        sendIdentity.creationDate = message.creationDate
                        sendIdentity.photoIdentifier = message.photoIdentifier
                        sendIdentity.remoteType = album.type
                        sendIdentity.messageIdentifier = message.messageIdentifier
                        sendIdentity.messageName = photo.remoteName
                        sendIdentity.remoteIdentifier = message.remoteIdentifier
                        sendIdentity.remoteName = message.remoteName
                        message.locked = true
                    }
                }
            }
        }
        if taskContext.hasChanges {
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.creationError
            }
        }
    }
    
    func dequeueAndUpdateSessionId(sessionId: UUID, folderType: FolderSource) async throws -> [SentPhotosProperties] {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updatingContext"
        taskContext.transactionAuthor = "updatingSending"
        let request = NSBatchUpdateRequest(entityName: "SendPhotoIdentity")
        request.propertiesToUpdate = ["sessionId": sessionId]
        request.resultType = .updatedObjectIDsResultType
        let firstreqExpr = NSExpression(forKeyPath: "remoteType")
        let secondreqExpr = NSExpression(forConstantValue:folderType.rawValue)
        let reqPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstreqExpr, rightExpression: secondreqExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo)
        request.predicate = reqPredicate
        do {
            guard let result = try taskContext.execute(request) as? NSBatchUpdateResult, let anyResult: Any = result.result else {
                throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Error of updating  of session id \(sessionId.uuidString)."])
            }
                guard  let objectsIdArray: [NSManagedObjectID] = anyResult as? [NSManagedObjectID] else {
                throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Error of updating  of session id \(sessionId.uuidString)."])
            }
            
            let fetchResult: [SendPhotoIdentity] = try await taskContext.perform({
                let fetchRequest = NSFetchRequest<SendPhotoIdentity>(entityName: "SendPhotoIdentity")
                let firstExpr = NSExpression(forKeyPath: "sessionId")
                let secondExpr = NSExpression(forConstantValue:sessionId)
                let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo)
                let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, reqPredicate])
                fetchRequest.predicate = compoundPredicate
                do {
                    return try taskContext.fetch(fetchRequest)
                } catch {
                    throw PhotoError.missingData
                }
            })
            if taskContext.hasChanges {
                try taskContext.save()
            }
            if fetchResult.count != objectsIdArray.count {
                print("Differences betwenn fetch results")
            }
            let finalResult: [SentPhotosProperties] = try fetchResult.map { (corePhoto: SendPhotoIdentity ) in
                guard let sendingSessionId: UUID = corePhoto.sessionId, sendingSessionId == sessionId else {
                    throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "session id must be equal to \(sessionId.uuidString)."])
                }
                let sendPhoto: SentPhotosProperties = SentPhotosProperties(id: corePhoto.photoIdentifier, photoName: corePhoto.photoName, albumIdentifier: corePhoto.albumIdentifier, creationDate: corePhoto.creationDate, latitude: corePhoto.latitude, longitude: corePhoto.longitude, image: corePhoto.image, remoteAlbumIdentifier: corePhoto.remoteAlbumIdentifier, remoteType: corePhoto.remoteType, sessionId: sendingSessionId)
                if let driveId: String = corePhoto.remoteDriveId {
                    sendPhoto.remoteDriveId = driveId
                }
                if let remoteName: String = corePhoto.remoteName {
                    sendPhoto.remoteName = remoteName
                }
                if let remoteIdentifier: String = corePhoto.remoteIdentifier {
                    sendPhoto.remoteIdentifier = remoteIdentifier
                }
                return sendPhoto
            }
            return finalResult
        } catch {
            throw error
        }
    }
    
    
    func dequeueAndUpdateSessionIdMessages(sessionId: UUID, folderType: FolderSource) async throws -> [SentMessageProperties] {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "updatingContextMessage"
        taskContext.transactionAuthor = "updatingSendingMessage"
        let request = NSBatchUpdateRequest(entityName: "SendMessageIdentity")
        request.propertiesToUpdate = ["sessionId": sessionId]
        request.resultType = .updatedObjectIDsResultType
        let firstreqExpr = NSExpression(forKeyPath: "remoteType")
        let secondreqExpr = NSExpression(forConstantValue:folderType.rawValue)
        let reqPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstreqExpr, rightExpression: secondreqExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo)
        request.predicate = reqPredicate
        do {
            guard let result = try taskContext.execute(request) as? NSBatchUpdateResult, let anyResult: Any = result.result else {
                throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Error of updating  of session id \(sessionId.uuidString)."])
            }
                guard  let objectsIdArray: [NSManagedObjectID] = anyResult as? [NSManagedObjectID] else {
                throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Error of updating  of session id \(sessionId.uuidString)."])
            }
            
            let fetchResult: [SendMessageIdentity] = try await taskContext.perform({
                let fetchRequest = NSFetchRequest<SendMessageIdentity>(entityName: "SendMessageIdentity")
                let firstExpr = NSExpression(forKeyPath: "sessionId")
                let secondExpr = NSExpression(forConstantValue:sessionId)
                let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo)
                let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, reqPredicate])
                fetchRequest.predicate = compoundPredicate
                do {
                    return try taskContext.fetch(fetchRequest)
                } catch {
                    throw PhotoError.missingData
                }
            })
            if taskContext.hasChanges {
                try taskContext.save()
            }
            if fetchResult.count != objectsIdArray.count {
                print("Differences betwenn fetch results")
            }
            let finalResult: [SentMessageProperties] = try fetchResult.map { (corePhoto: SendMessageIdentity ) in
                guard let sendingSessionId: UUID = corePhoto.sessionId, sendingSessionId == sessionId else {
                    throw NSError(domain: "Core Data", code: 2001, userInfo: [NSLocalizedDescriptionKey: "session id must be equal to \(sessionId.uuidString)."])
                }
                let sendMessage: SentMessageProperties = SentMessageProperties(id: corePhoto.messageIdentifier, messageName: corePhoto.messageName, albumIdentifier: corePhoto.albumIdentifier, creationDate: corePhoto.creationDate,  text: corePhoto.text, remoteAlbumIdentifier: corePhoto.remoteAlbumIdentifier, remoteType: corePhoto.remoteType, sessionId: sendingSessionId)
                if let driveId: String = corePhoto.remoteDriveId {
                    sendMessage.remoteDriveId = driveId
                }
                if let remoteId: String = corePhoto.remoteIdentifier {
                    sendMessage.remoteIdentifier = remoteId
                }
                if let remoteName: String = corePhoto.remoteName {
                    sendMessage.remoteName = remoteName
                }
                return sendMessage
            }
            return finalResult
        } catch {
            throw error
        }
    }
    
    func deleteSentPhotos(_ sentPhoto: SyncPhotosProperties) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "deletingContext"
        taskContext.transactionAuthor = "deletingSending"
        let result: [SendPhotoIdentity] = try await taskContext.perform({
            let request = NSFetchRequest<SendPhotoIdentity>(entityName: "SendPhotoIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "photoIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: sentPhoto.id)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "sessionId")
            let secondExpr = NSExpression(forConstantValue: sentPhoto.sessionId)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                return try taskContext.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
            
        })
        guard let sentItem: SendPhotoIdentity = result.first  else {
            throw PhotoError.missingData
        }
        
        try await taskContext.perform {
            let request = NSFetchRequest<PhotoIdentity>(entityName: "PhotoIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "photoIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: sentPhoto.id)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr2 = NSExpression(forKeyPath: "photoName")
            let secondExpr2 = NSExpression(forConstantValue: sentPhoto.photoName)
            let seconfPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr2, rightExpression: secondExpr2, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, seconfPredicate])
            request.predicate = compoundPredicate
            let objects = try taskContext.fetch(request)
            guard let photo: PhotoIdentity = objects.first else {
                throw PhotoError.updateError
            }
            photo.remoteIdentifier = sentPhoto.remoteId
            photo.remoteName = sentPhoto.remoteName
            taskContext.delete(sentItem)
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.updateError
            }
        }
    }
    
    func deleteSentMessages(_ sentPhoto: SyncPhotosProperties) async throws {
        let taskContext: NSManagedObjectContext = self.newBackgroundTaskContext()
        taskContext.name = "deletingContext"
        taskContext.transactionAuthor = "deletingSending"
        let result: [SendMessageIdentity] = try await taskContext.perform({
            let request = NSFetchRequest<SendMessageIdentity>(entityName: "SendMessageIdentity")
            let firstExpr1 = NSExpression(forKeyPath: "messageIdentifier")
            let secondExpr1 = NSExpression(forConstantValue: sentPhoto.id)
            let firstPredicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr1, rightExpression: secondExpr1, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            let firstExpr = NSExpression(forKeyPath: "sessionId")
            let secondExpr = NSExpression(forConstantValue: sentPhoto.sessionId)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo)
            let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [firstPredicate, predicate])
            request.predicate = compoundPredicate
            do {
                return try taskContext.fetch(request)
            } catch {
                throw PhotoError.missingData
            }
        })
        guard let sentItem: SendMessageIdentity = result.first  else {
            throw PhotoError.missingData
        }
        
        try await taskContext.perform {
            let request = NSFetchRequest<MessageIdentity>(entityName: "MessageIdentity")
            let firstExpr = NSExpression(forKeyPath: "messageIdentifier")
            let secondExpr = NSExpression(forConstantValue: sentPhoto.id)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            request.predicate = predicate
            let objects = try taskContext.fetch(request)
            guard let message: MessageIdentity = objects.first else {
                throw PhotoError.updateError
            }
            message.remoteIdentifier = sentPhoto.remoteId
            message.remoteName = sentPhoto.remoteName
            taskContext.delete(sentItem)
            do {
                try taskContext.save()
            } catch {
                throw PhotoError.updateError
            }
        }
    }
}
