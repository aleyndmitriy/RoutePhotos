//
//  PhotosGoogleDriveSender.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 27.09.2022.
//

import UIKit
import GoogleSignIn

class PhotosGoogleDriveSender: NSObject {
    static let shared = PhotosGoogleDriveSender()
    private var authViewModel = AuthenticationGoogleViewModel()
    private let googleOneDriveService = GoogleOneDriveService()
    private let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
    var isCancel: Bool = false
    
    private override init() {
        super.init()
    }
    
    func synchronization() async throws {
            do {
                try await CoreDataSyncAssetDatabase.shared.enqueuePhotos(folderType: .googledrive)
                var newId: UUID = UUID()
                let sendingPhotos: [SentPhotosProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionId(sessionId: newId, folderType: .googledrive)
                let sendingDrivePhotos: [SentPhotosProperties] = sendingPhotos.filter { (property: SentPhotosProperties) in
                    return property.remoteType == FolderSource.googledrive.rawValue
                }
                
                if sendingDrivePhotos.isEmpty == false {
                    let user = try await authViewModel.restorePreviousGoogleSign()
                    if authViewModel.hasGoogleDriveFilesScope {
                        self.googleOneDriveService.fetchServiceAutorization(user: user)
                    }
                    for sendingPhoto in sendingDrivePhotos {
                        do {
                            let sentPhoto = try await self.googleOneDriveService.uploadFile(sendigPhoto: sendingPhoto)
                            try await CoreDataSyncAssetDatabase.shared.deleteSentPhotos(sentPhoto)
                        } catch {
                            print("photo with \(sendingPhoto.photoName) for google drive has not been uploaded with error\(error.localizedDescription)")
                        }
                    }
                }
               
                try await CoreDataSyncAssetDatabase.shared.enqueueMessage(folderType: .googledrive)
                newId = UUID()
                let sendingMessages: [SentMessageProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionIdMessages(sessionId: newId, folderType: .googledrive)
                
                let sendingDriveMessages: [SentMessageProperties] = sendingMessages.filter { (property: SentMessageProperties) in
                    return property.remoteType == FolderSource.googledrive.rawValue
                }
                if sendingDriveMessages.isEmpty == false {
                    if sendingDrivePhotos.isEmpty {
                        let user = try await authViewModel.restorePreviousGoogleSign()
                        if authViewModel.hasGoogleDriveFilesScope {
                            self.googleOneDriveService.fetchServiceAutorization(user: user)
                        }
                    }
                    for sendingDriveMessage in sendingDriveMessages {
                        do {
                            let sentMessage = try await self.googleOneDriveService.uploadFile(sendigMessage: sendingDriveMessage)
                            try await CoreDataSyncAssetDatabase.shared.deleteSentMessages(sentMessage)
                            if isCancel {
                                return
                            }
                        } catch {
                            print("photo with \(sendingDriveMessage.messageName) for google drive has not been uploaded with error\(error.localizedDescription)")
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
            try await CoreDataSyncAssetDatabase.shared.enqueuePhotos(folderType: .googledrive)
            if isCancel {
                return
            }
            var newId: UUID = UUID()
            let sendingPhotos: [SentPhotosProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionId(sessionId: newId, folderType: .googledrive)
            if isCancel {
                return
            }
            let sendingDrivePhotos: [SentPhotosProperties] = sendingPhotos.filter { (property: SentPhotosProperties) in
                return property.remoteType == FolderSource.googledrive.rawValue
            }
            if isCancel {
                return
            }
            
            if sendingDrivePhotos.isEmpty == false {
                let user = try await authViewModel.restorePreviousGoogleSign()
                if authViewModel.hasGoogleDriveFilesScope {
                    self.googleOneDriveService.fetchServiceAutorization(user: user)
                }
                for sendingPhoto in sendingDrivePhotos {
                    do {
                        let sentPhoto = try await self.googleOneDriveService.uploadFile(sendigPhoto: sendingPhoto)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentPhotos(sentPhoto)
                        uploadedNumber += 1
                        if isCancel {
                            self.createNotification(addToSync: sendingDrivePhotos.count, uploaded: uploadedNumber)
                            return
                        }
                    } catch {
                        print("photo with \(sendingPhoto.photoName) for google drive has not been uploaded with error\(error.localizedDescription)")
                    }
                    
                }
            }
            
            if isCancel && sendingDrivePhotos.isEmpty == false {
                self.createNotification(addToSync: sendingDrivePhotos.count, uploaded: uploadedNumber)
            }
            try await CoreDataSyncAssetDatabase.shared.enqueueMessage(folderType: .googledrive)
            newId = UUID()
            let sendingMessages: [SentMessageProperties] = try await CoreDataSyncAssetDatabase.shared.dequeueAndUpdateSessionIdMessages(sessionId: newId, folderType: .googledrive)
            if isCancel {
                return
            }
            let sendingDriveMessages: [SentMessageProperties] = sendingMessages.filter { (property: SentMessageProperties) in
                return property.remoteType == FolderSource.googledrive.rawValue
            }
            if isCancel {
                return
            }
            if sendingDriveMessages.isEmpty == false {
                if sendingDrivePhotos.isEmpty {
                    let user = try await authViewModel.restorePreviousGoogleSign()
                    if authViewModel.hasGoogleDriveFilesScope {
                        self.googleOneDriveService.fetchServiceAutorization(user: user)
                    }
                }
                for sendingDriveMessage in sendingDriveMessages {
                    do {
                        let sentMessage = try await self.googleOneDriveService.uploadFile(sendigMessage: sendingDriveMessage)
                        try await CoreDataSyncAssetDatabase.shared.deleteSentMessages(sentMessage)
                        if isCancel {
                            return
                        }
                    } catch {
                        print("photo with \(sendingDriveMessage.messageName) for google drive has not been uploaded with error\(error.localizedDescription)")
                    }
                }
            }
           
            if sendingDrivePhotos.isEmpty == false {
                self.createNotification(addToSync: sendingDrivePhotos.count, uploaded: uploadedNumber)
            }
        } catch {
            throw error
        }
    }
    
    private func createNotification(addToSync: Int, uploaded: Int) {
        let content = UNMutableNotificationContent()
        content.title = "New Photos have been uploaded!"
        content.body = String(format: "%d photos was added for uploading; %d photos has been uploaded to GoogleDrive.", addToSync,uploaded)
        content.sound = .default
        //let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        center.add(request, withCompletionHandler: nil)
    }
}
