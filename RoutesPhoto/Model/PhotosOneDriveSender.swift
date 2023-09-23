//
//  PhotosOneDriveSender.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 14.11.2022.
//

import UIKit

class PhotosOneDriveSender: NSObject {
    static let shared = PhotosOneDriveSender()
    var authViewModel = AuthenticationOneDriveModel()
    private let oneDriveService = MicroSoftOneDriveService()
    
    private let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
    var isCancel: Bool = false
    
    private override init() {
        super.init()
    }
    
    func synchronization() async throws {
        do {
            try await CoreDataSyncAssetDatabase.shared.enqueuePhotos(folderType: .onedrive)
            var newId: UUID = UUID()
            let sendingPhotos: [SentPhotosProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionId(sessionId: newId, folderType: .onedrive)
            let sendingOneDrivePhotos: [SentPhotosProperties] = sendingPhotos.filter { (property: SentPhotosProperties) in
                return property.remoteType == FolderSource.onedrive.rawValue
            }
            
            if sendingOneDrivePhotos.isEmpty == false {
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                for sendingPhoto in sendingOneDrivePhotos {
                    do {
                        let sentPhoto = try await self.oneDriveService.uploadFile(sendigPhoto: sendingPhoto)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentPhotos(sentPhoto)
                    } catch {
                        print("photo with \(sendingPhoto.photoName) for on has not been on OneDrive uploaded with error\(error.localizedDescription)")
                    }
                }
            }
           
            try await CoreDataSyncAssetDatabase.shared.enqueueMessage(folderType: .onedrive)
            newId = UUID()
            let sendingMessages: [SentMessageProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionIdMessages(sessionId: newId, folderType: .onedrive)
            let sendingOneDriveMessages: [SentMessageProperties] = sendingMessages.filter { (property: SentMessageProperties) in
                return property.remoteType == FolderSource.onedrive.rawValue
            }
            
            if sendingOneDriveMessages.isEmpty == false {
                try await CoreDataSyncAssetDatabase.shared.enqueueMessage(folderType: .onedrive)
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                for sendingOneDriveMessage in sendingOneDriveMessages {
                    do {
                        let sentMessage = try await self.oneDriveService.uploadFile(sendigMessage: sendingOneDriveMessage)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentMessages(sentMessage)
                    } catch {
                        print("photo with \(sendingOneDriveMessage.messageName) for on has not been on OneDrive uploaded with error\(error.localizedDescription)")
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
            try await CoreDataSyncAssetDatabase.shared.enqueuePhotos(folderType: .onedrive)
            if isCancel {
                return
            }
            var newId: UUID = UUID()
            let sendingPhotos: [SentPhotosProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionId(sessionId: newId, folderType: .onedrive)
            if isCancel {
                return
            }
            let sendingOneDrivePhotos: [SentPhotosProperties] = sendingPhotos.filter { (property: SentPhotosProperties) in
                return property.remoteType == FolderSource.onedrive.rawValue
            }
            
            if sendingOneDrivePhotos.isEmpty == false {
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                for sendingPhoto in sendingOneDrivePhotos {
                    do {
                        let sentPhoto = try await self.oneDriveService.uploadFile(sendigPhoto: sendingPhoto)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentPhotos(sentPhoto)
                        uploadedNumber += 1
                        if isCancel {
                            self.createNotification(addToSync: sendingOneDrivePhotos.count, uploaded: uploadedNumber)
                            return
                        }
                    } catch {
                        print("photo with \(sendingPhoto.photoName) for on has not been uploaded on OneDrive with error\(error.localizedDescription)")
                    }
                }
            }
            
            if isCancel && sendingOneDrivePhotos.isEmpty == false {
                self.createNotification(addToSync: sendingOneDrivePhotos.count, uploaded: uploadedNumber)
            }
            
            try await CoreDataSyncAssetDatabase.shared.enqueueMessage(folderType: .onedrive)
            newId = UUID()
            let sendingMessages: [SentMessageProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionIdMessages(sessionId: newId, folderType: .onedrive)
            if isCancel {
                return
            }
            let sendingOneDriveMessages: [SentMessageProperties] = sendingMessages.filter { (property: SentMessageProperties) in
                return property.remoteType == FolderSource.onedrive.rawValue
            }
            
            if sendingOneDriveMessages.isEmpty == false {
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                for sendingOneDriveMessage in sendingOneDriveMessages {
                    do {
                        let sentMessage = try await self.oneDriveService.uploadFile(sendigMessage: sendingOneDriveMessage)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentMessages(sentMessage)
                        if isCancel {
                            return
                        }
                    } catch {
                        print("photo with \(sendingOneDriveMessage.messageName) for on has not been on OneDrive uploaded with error\(error.localizedDescription)")
                    }
                }
            }
            
            if sendingOneDrivePhotos.isEmpty == false {
                self.createNotification(addToSync: sendingOneDrivePhotos.count, uploaded: uploadedNumber)
            }
            
        } catch {
            throw error
        }
    }
    
    private func createNotification(addToSync: Int, uploaded: Int) {
        let content = UNMutableNotificationContent()
        content.title = "New Photos have been uploaded!"
        content.body = String(format: "%d photos was added for uploading; %d photos has been uploaded to OneDrive.", addToSync,uploaded)
        content.sound = .default
        //let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        center.add(request, withCompletionHandler: nil)
    }
}
