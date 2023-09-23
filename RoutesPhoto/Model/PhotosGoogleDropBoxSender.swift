//
//  PhotosGoogleDropBoxSender.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 29.10.2022.
//

import UIKit

class PhotosGoogleDropBoxSender: NSObject {
    static let shared = PhotosGoogleDropBoxSender()
    var authViewModel = AuthenticationDropBoxModel()
    private let googleDropBoxService = GoogleDropBoxService()
    
    private let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
    var isCancel: Bool = false
    
    private override init() {
        super.init()
    }
    
    func synchronization() async throws {
            do {
                try await CoreDataSyncAssetDatabase.shared.enqueuePhotos(folderType: .dropbox)
                var newId: UUID = UUID()
                let sendingPhotos: [SentPhotosProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionId(sessionId: newId, folderType: .dropbox)
                let sendingDropBoxPhotos: [SentPhotosProperties] = sendingPhotos.filter { (property: SentPhotosProperties) in
                    return property.remoteType == FolderSource.dropbox.rawValue
                }
                
                if sendingDropBoxPhotos.isEmpty == false {
                    guard let client = authViewModel.currentClient() else {
                        throw NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
                    }
                    googleDropBoxService.client = client
                    for sendingPhoto in sendingDropBoxPhotos {
                        do {
                            let sentPhoto = try await self.googleDropBoxService.uploadFile(sendigPhoto: sendingPhoto)
                            try await CoreDataSyncAssetDatabase.shared.deleteSentPhotos(sentPhoto)
                        } catch {
                            print("photo with \(sendingPhoto.photoName) for dropbox has not been uploaded with error\(error.localizedDescription)")
                        }
                    }
                }
                try await CoreDataSyncAssetDatabase.shared.enqueueMessage(folderType: .dropbox)
                newId = UUID()
                let sendingMessages: [SentMessageProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionIdMessages(sessionId: newId, folderType: .dropbox)
                let sendingDropBoxMessages: [SentMessageProperties] = sendingMessages.filter { (property: SentMessageProperties) in
                    return property.remoteType == FolderSource.dropbox.rawValue
                }
                if sendingDropBoxMessages.isEmpty == false {
                    guard let client = authViewModel.currentClient() else {
                        throw NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
                    }
                    googleDropBoxService.client = client
                    for sendingMessage in sendingDropBoxMessages {
                        do {
                            let sentMessage = try await self.googleDropBoxService.uploadFile(sendigMessage: sendingMessage)
                            try await CoreDataSyncAssetDatabase.shared.deleteSentMessages(sentMessage)
                        } catch {
                            print("photo with \(sendingMessage.messageName) for dropbox has not been uploaded with error\(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                throw error
            }
    }
    
    
    func backgroundSynchronization() async throws {
        do {
            var uploadedNumber: Int = 0
            try await CoreDataSyncAssetDatabase.shared.enqueuePhotos(folderType: .dropbox)
            if isCancel {
                return
            }
            var newId: UUID = UUID()
            let sendingPhotos: [SentPhotosProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionId(sessionId: newId, folderType: .dropbox)
            if isCancel {
                return
            }
            let sendingDropBoxPhotos: [SentPhotosProperties] = sendingPhotos.filter { (property: SentPhotosProperties) in
                return property.remoteType == FolderSource.dropbox.rawValue
            }
            
            if sendingDropBoxPhotos.isEmpty == false {
                guard let client = authViewModel.currentClient() else {
                    throw NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
                }
                googleDropBoxService.client = client
                for sendingPhoto in sendingDropBoxPhotos {
                    do {
                        let sentPhoto = try await self.googleDropBoxService.uploadFile(sendigPhoto: sendingPhoto)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentPhotos(sentPhoto)
                        uploadedNumber += 1
                        if isCancel {
                            self.createNotification(addToSync: sendingDropBoxPhotos.count, uploaded: uploadedNumber)
                            return
                        }
                    } catch {
                        print("photo with \(sendingPhoto.photoName) for dropbox has not been uploaded with error\(error.localizedDescription)")
                    }
                }
            }
            
            if isCancel && sendingDropBoxPhotos.isEmpty == false {
                self.createNotification(addToSync: sendingDropBoxPhotos.count, uploaded: uploadedNumber)
            }
            
            try await CoreDataSyncAssetDatabase.shared.enqueueMessage(folderType: .dropbox)
            newId = UUID()
            let sendingMessages: [SentMessageProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionIdMessages(sessionId: newId, folderType: .dropbox)
            if isCancel {
                return
            }
            let sendingDropBoxMessages: [SentMessageProperties] = sendingMessages.filter { (property: SentMessageProperties) in
                return property.remoteType == FolderSource.dropbox.rawValue
            }
            
            if sendingDropBoxMessages.isEmpty == false {
                guard let client = authViewModel.currentClient() else {
                    throw NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
                }
                googleDropBoxService.client = client
                for sendingMessage in sendingDropBoxMessages {
                    do {
                        let sentMessage = try await self.googleDropBoxService.uploadFile(sendigMessage: sendingMessage)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentMessages(sentMessage)
                        if isCancel {
                            return
                        }
                    } catch {
                        print("photo with \(sendingMessage.messageName) for dropbox has not been uploaded with error\(error.localizedDescription)")
                    }
                }
            }
            if sendingDropBoxPhotos.isEmpty == false {
                self.createNotification(addToSync: sendingDropBoxPhotos.count, uploaded: uploadedNumber)
            }
        } catch {
            throw error
        }
    }
    
    private func createNotification(addToSync: Int, uploaded: Int) {
        let content = UNMutableNotificationContent()
        content.title = "New Photos have been uploaded!"
        content.body = String(format: "%d photos was added for uploading; %d photos has been uploaded to DropBox.", addToSync,uploaded)
        content.sound = .default
        //let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        center.add(request, withCompletionHandler: nil)
    }
}
