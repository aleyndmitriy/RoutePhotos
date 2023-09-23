//
//  Persistence.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 19.06.2022.
//

import OSLog
import CoreData
import UIKit
import CoreLocation
import CloudKit

protocol PersistenceControllerOutput: AnyObject {
    func beginSending()
    func endSending(error: String?)
}

class PersistenceController {
    let directory: String = "PointofSalesPhoto"
    let logger = Logger(subsystem: "com.example.newLine-samplecode.RoutePhoto", category: "persistence")
    let iCloudContainer: CKContainer
    let publicDB: CKDatabase
    
    var persistenceControllerOutput: PersistenceControllerOutput?
    
    static let shared = PersistenceController(inMemory: false)

    static var preview: PersistenceController = {
        
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        var photos = [PhotoItem]()
        for _ in 0..<10 {
            let newItem = PhotoItem(context: viewContext)
            newItem.timestamp = Date()
            if let img: UIImage = UIImage(named: "chincoteague") {
                newItem.image = img.pngData()
            }
            newItem.latitude = 34.011_286
            newItem.longitude = -116.166_868
            photos.append(newItem)
        }
        return result
    }()
    
    static var photoDetailPreview: PhotoItem  = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let newItem = PhotoItem(context: viewContext)
        newItem.timestamp = Date()
        if let img: UIImage = UIImage(named: "chincoteague") {
            newItem.image = img.pngData()
        }
        newItem.latitude = 34.011_286
        newItem.longitude = -116.166_868
        return newItem
    }()
    
    let container: NSPersistentContainer
    private var notificationToken: NSObjectProtocol?
    private var lastToken: NSPersistentHistoryToken?
    private var photosArray: [PhotosProperties] = [PhotosProperties]()
    private let filesInteractor: FilesInteractor
    let locationManager: CLLocationManager = CLLocationManager()
    
    private init(inMemory: Bool) {
        self.filesInteractor = FilesInteractor()
        self.iCloudContainer = CKContainer.default()
        self.publicDB = self.iCloudContainer.publicCloudDatabase
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        container = NSPersistentContainer(name: "RoutesPhoto")
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        description.setOption(true as NSNumber,
                              forKey: NSPersistentHistoryTrackingKey)
        
        container.viewContext.automaticallyMergesChangesFromParent = false
        container.viewContext.name = "viewContext"
        /// - Tag: viewContextMergePolicy
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        notificationToken = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { note in
            self.logger.debug("Received a persistent store remote change notification.")
            Task {
                await self.fetchPersistentHistory()
            }
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
    
    deinit {
        if let observer = notificationToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func fetchPersistentHistory() async {
        do {
            try await fetchPersistentHistoryTransactionsAndChanges()
        } catch {
            logger.debug("\(error.localizedDescription)")
        }
    }

    private func newTaskContext() -> NSManagedObjectContext {
        // Create a private queue context.
        /// - Tag: newBackgroundContext
        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        taskContext.undoManager = nil
        return taskContext
    }
    
    private func fetchPersistentHistoryTransactionsAndChanges() async throws {
        let taskContext = newTaskContext()
        taskContext.name = "persistentHistoryContext"
        logger.debug("Start fetching persistent history changes from the store...")

        try await taskContext.perform {
            // Execute the persistent history change since the last transaction.
            /// - Tag: fetchHistory
            let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
            let historyResult = try taskContext.execute(changeRequest) as? NSPersistentHistoryResult
            if let history = historyResult?.result as? [NSPersistentHistoryTransaction],
               !history.isEmpty {
                self.mergePersistentHistoryChanges(from: history)
                return
            }

            self.logger.debug("No persistent history transactions found.")
            throw PhotoError.persistentHistoryChangeError
        }

        logger.debug("Finished merging history changes.")
    }

    private func mergePersistentHistoryChanges(from history: [NSPersistentHistoryTransaction]) {
        self.logger.debug("Received \(history.count) persistent history transactions.")
        // Update view context with objectIDs from history change request.
        /// - Tag: mergeChanges
        let viewContext = container.viewContext
        viewContext.perform {
            for transaction in history {
                viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                self.lastToken = transaction.token
            }
        }
    }
    
    func fetchPhotos() async throws {
        try await importPhotos(from: self.photosArray)
        self.photosArray.removeAll()
        logger.debug("Finished importing data.")
        throw PhotoError.batchInsertError
    }
    
    private func importPhotos(from propertiesList: [PhotosProperties]) async throws {
        guard !propertiesList.isEmpty else { return }
        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importPhotos"

        /// - Tag: performAndWait
        try await taskContext.perform {
            // Execute the batch insert.
            /// - Tag: batchInsertRequest
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool, success {
                
                return
            }
            self.logger.debug("Failed to execute batch insert request.")
            throw PhotoError.batchInsertError
        }
        logger.debug("Successfully inserted data.")
    }
    
    private func newBatchInsertRequest(with photoList: [PhotosProperties]) -> NSBatchInsertRequest {
        var index = 0
        let total = photoList.count

        // Provide one dictionary at a time when the closure is called.
        let batchInsertRequest = NSBatchInsertRequest(entity: PhotoItem.entity()) { (object: NSManagedObject) -> Bool in
            guard index < total else { return true }
            if let photo: PhotoItem = object as? PhotoItem {
                photo.id = photoList[index].id
                photo.timestamp = photoList[index].date
                photo.latitude = photoList[index].latitude
                photo.longitude = photoList[index].longitude
                photo.image = photoList[index].image
            }
            index += 1
            return false
        }
        
        return batchInsertRequest
    }
    
    func deletePhotos(_ photos: [PhotoItem]) async throws {
        let objectIDs = photos.map { $0.objectID }
        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "deleteContext"
        taskContext.transactionAuthor = "deletePhotos"
        logger.debug("Start deleting data from the store...")

        try await taskContext.perform {
            // Execute the batch delete.
            let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: objectIDs)
            guard let fetchResult = try? taskContext.execute(batchDeleteRequest),
                  let batchDeleteResult = fetchResult as? NSBatchDeleteResult,
                  let success = batchDeleteResult.result as? Bool, success
            else {
                self.logger.debug("Failed to execute batch delete request.")
                throw PhotoError.batchDeleteError
            }
        }

        logger.debug("Successfully deleted data.")
    }
    
    func addPhoto(_ img: CIImage) {
        let image: UIImage = UIImage(ciImage: img)
        guard let imgData: Data = image.pngData() else {
            return
        }
        if let location: CLLocation = self.locationManager.location {
            self.photosArray.append(PhotosProperties(image: imgData, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude))
        }
        else {
            self.photosArray.append(PhotosProperties(image: imgData))
        }
    }
    
    
    
    func deletePhotoItems(identifiedBy objectIDs: [NSManagedObjectID]) {
        let viewContext = container.viewContext
        logger.debug("Start deleting data from the store...")

        viewContext.perform {
            objectIDs.forEach { objectID in
                let photo = viewContext.object(with: objectID)
                viewContext.delete(photo)
                do {
                    try viewContext.save()
                }
                catch {
                    self.logger.debug("\(PhotoError.batchDeleteError.localizedDescription)")
                }
            }
        }
        logger.debug("Successfully deleted data.")
    }
    
    private func deletePhoto(id: UUID) throws {
        let taskContext = newTaskContext()
        taskContext.name = "deletePhotoId"
        taskContext.transactionAuthor = "deleteTransactionPhotoId"
        let request = NSFetchRequest<PhotoItem>(entityName: "PhotoItem")
        let firstExpr = NSExpression(forKeyPath: "id")
        let secondExpr = NSExpression(forConstantValue: id)
        let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: [])
        request.predicate = predicate
        do {
            let result: [PhotoItem] = try taskContext.fetch(request)
            if result.count > 0 {
                for photoItem: PhotoItem in result {
                    taskContext.delete(photoItem)
                }
                do {
                    try taskContext.save()
                }
                catch {
                    self.logger.debug("\(PhotoError.batchDeleteError.localizedDescription)")
                }
            }
        }
        catch {
            self.logger.debug("Failed to fetch request items with UUID")
            throw PhotoError.missingData
        }
    }
    
    public func createAssets() throws {
        let taskContext = newTaskContext()
        taskContext.name = "createPhotoAssetsContext"
        taskContext.transactionAuthor = "createPhotoAssets"
        let request = NSFetchRequest<PhotoItem>(entityName: "PhotoItem")
        request.predicate = NSPredicate(format: "temporaryURL = nil")
        do {
            let result: [PhotoItem] = try taskContext.fetch(request)
            if result.count > 0 {
                for photoItem: PhotoItem in result {
                    if let data: Data = photoItem.image, let imgUUID: UUID = photoItem.id {
                        if let path: URL = filesInteractor.saveFile(data: data, directory: directory, fileName: imgUUID.uuidString) {
                            photoItem.temporaryURL = path
                        }
                    }
                }
                if taskContext.hasChanges {
                    do {
                        try taskContext.save()
                    }
                    catch {
                        self.logger.debug("\(PhotoError.updateError.localizedDescription)")
                    }
                }
            }
        }
        catch {
            self.logger.debug("Failed to fetch request items with .temporaryURL = nil")
            throw PhotoError.missingData
        }
    }
    
    public func createAsset(item: PhotoItem) throws {
        self.persistenceControllerOutput?.beginSending()
        let taskContext = newTaskContext()
        taskContext.name = "createPhotoAssetsContext"
        taskContext.transactionAuthor = "createPhotoAssets"
        let firstExpr = NSExpression(forKeyPath: "id")
        let secondExpr = NSExpression(forConstantValue: item.id)
        let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: [])
        let request = NSFetchRequest<PhotoItem>(entityName: "PhotoItem")
        request.predicate = predicate
        do {
            let result: [PhotoItem] = try taskContext.fetch(request)
            if result.count == 1  {
                for photoItem: PhotoItem in result {
                    if let data: Data = photoItem.image, let imgUUID: UUID = photoItem.id, photoItem.temporaryURL == nil {
                        if let path: URL = filesInteractor.saveFile(data: data, directory: directory, fileName: imgUUID.uuidString) {
                            photoItem.temporaryURL = path
                        }
                    }
                }
                if taskContext.hasChanges {
                    do {
                        try taskContext.save()
                    }
                    catch {
                        self.logger.debug("\(PhotoError.updateError.localizedDescription)")
                        self.persistenceControllerOutput?.endSending(error: "\(PhotoError.updateError.localizedDescription)")
                    }
                }
            }
        }
        catch {
            self.logger.debug("Failed to fetch request items with .temporaryURL = nil")
            self.persistenceControllerOutput?.endSending(error: "Failed to fetch request items with .temporaryURL = nil")
            throw PhotoError.missingData
        }
        
        do {
            try sendPhoto(item: item)
        }
        catch {
            self.logger.debug("\(PhotoError.updateError.localizedDescription)")
            self.persistenceControllerOutput?.endSending(error: "\(PhotoError.updateError.localizedDescription)")
        }
    }
    
    
    private func sendPhotos() throws {
        let taskContext = newTaskContext()
        taskContext.name = "fetchPhotoAssetsContext"
        taskContext.transactionAuthor = "fetchPhotoAssets"
        let request = NSFetchRequest<PhotoItem>(entityName: "PhotoItem")
        request.predicate = NSPredicate(format: "temporaryURL != nil")
        do {
            let result: [PhotoItem] = try taskContext.fetch(request)
            if result.count > 0 {
                for photoItem: PhotoItem in result {
                    if let url: URL = photoItem.temporaryURL, let imgUUID: UUID = photoItem.id {
                        let record: CKRecord = CKRecord(recordType: "CD_PhotoItem")
                        record["CD_id"] = imgUUID.uuidString
                        record["CD_timestamp"] = photoItem.timestamp
                        record["CD_latitude"] = photoItem.latitude
                        record["CD_longitude"] = photoItem.longitude
                        let asset =  CKAsset(fileURL: url)
                        record["CD_image_ckAsset"] = asset
                        self.publicDB.save(record, completionHandler: self.deleteAfterSaving(record:error:))
                    }
                }
            }
        }
        catch {
            self.logger.debug("Failed to fetch request items with .temporaryURL != nil")
            throw PhotoError.missingData
        }
    }
    
    public func sendPhoto(item: PhotoItem) throws {
        let taskContext = newTaskContext()
        taskContext.name = "fetchPhotoAssetsContext"
        taskContext.transactionAuthor = "fetchPhotoAssets"
        let request = NSFetchRequest<PhotoItem>(entityName: "PhotoItem")
        let firstExpr = NSExpression(forKeyPath: "id")
        let secondExpr = NSExpression(forConstantValue: item.id)
        let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: [])
        request.predicate = predicate
        do {
            let result: [PhotoItem] = try taskContext.fetch(request)
            if result.count == 1 {
                for photoItem: PhotoItem in result {
                    if let url: URL = photoItem.temporaryURL, let imgUUID: UUID = photoItem.id, photoItem.temporaryURL != nil {
                        let record: CKRecord = CKRecord(recordType: "CD_PhotoItem")
                        record["CD_id"] = imgUUID.uuidString
                        record["CD_timestamp"] = photoItem.timestamp
                        record["CD_latitude"] = photoItem.latitude
                        record["CD_longitude"] = photoItem.longitude
                        let asset =  CKAsset(fileURL: url)
                        record["CD_image_ckAsset"] = asset
                        self.publicDB.save(record, completionHandler: self.deleteAfterSaving(record:error:))
                    }
                }
            }
        }
        catch {
            self.logger.debug("Failed to fetch request items with .temporaryURL != nil")
            throw PhotoError.missingData
        }
    }
    
    
    private func deleteAfterSaving(record: CKRecord?, error: Error?) {
        if let savingRecord: CKRecord = record {
            if let fileName: String = savingRecord["CD_id"] as? String, let id: UUID = UUID(uuidString: fileName), filesInteractor.deleteFile(directory: directory, fileName: fileName) {
                do {
                    try deletePhoto(id: id)
                }
                catch {
                    self.logger.debug("\(PhotoError.batchDeleteError.localizedDescription)")
                    self.persistenceControllerOutput?.endSending(error: "\(PhotoError.batchDeleteError.localizedDescription)")
                }
            }
            self.logger.debug("\(savingRecord.recordID)")
            self.persistenceControllerOutput?.endSending(error: nil)
        }
        if let err: Error = error {
            self.logger.debug("\(err.localizedDescription)")
            self.persistenceControllerOutput?.endSending(error: "\(err.localizedDescription)")
            
        }
    }
}
