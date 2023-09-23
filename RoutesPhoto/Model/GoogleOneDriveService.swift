//
//  GoogleOneDriveService.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.08.2022.
//

import Foundation
import SwiftUI
import GoogleAPIClientForREST_Drive
import GoogleSignIn

class GoogleOneDriveService: NSObject {
    
    var serviceError: Error?
     var progressValue: Float = 0.0
     var progressValueTotal: Float = 1.0
     var isProcessing: Bool = false
    var isFinished: Bool = false
     var message: String = String()
     var numberFilesForUploading: Int = -1
    private let googleDriveService = GTLRDriveService()
    
    override init() {
        super.init()
    }
    
    func fetchServiceAutorization(user: GIDGoogleUser) {
        googleDriveService.authorizer = user.authentication.fetcherAuthorizer()
    }
    
    private func searchChildRootFolder(folderName: String) async -> RemoteFolderItem? {
        self.serviceError = nil
        let query1: GTLRDriveQuery_FilesList = GTLRDriveQuery_FilesList.query()
        query1.fields = "files(id,name,capabilities(canEdit))"
        query1.supportsAllDrives = true
        query1.spaces = "drive"
        query1.q = "name = '\(folderName)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false and ('root' in parents or sharedWithMe = true)"
        return await withCheckedContinuation { continuation in
            self.googleDriveService.executeQuery(query1) { (ticket, result, error) in
                guard  let res: Any = result, let folders: GTLRDrive_FileList = res as? GTLRDrive_FileList, error == nil  else {
                    print("Error of finding folder with name \(folderName) on google drive")
                    self.serviceError = error
                    continuation.resume(returning: nil)
                    return
                }
                guard let identifier: String = folders.files?.first?.identifier, let name = folders.files?.first?.name, folderName == name  else {
                    self.serviceError = NSError(domain: "Google sync module module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Folder with name \(folderName) has not been found."])
                    continuation.resume(returning: nil)
                    return
                }
                let canEdit: Bool = folders.files?.first?.capabilities?.canEdit.map({ $0.boolValue }) ?? false
                continuation.resume(returning: RemoteFolderItem(id: identifier,name: name, source: .googledrive, canEdit: canEdit))
            }
        }
    }
    
    
    private func searchFolderWithParent(folderName: String, parentID: String) async -> RemoteFolderItem? {
        self.serviceError = nil
        let query1: GTLRDriveQuery_FilesList = GTLRDriveQuery_FilesList.query()
        query1.fields = "files(id,name,capabilities(canEdit))"
        query1.supportsAllDrives = true
        query1.spaces = "drive"
        query1.q = "name = '\(folderName)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false and '\(parentID)' in parents"
        return await withCheckedContinuation { continuation in
            self.googleDriveService.executeQuery(query1) { (ticket, result, error) in
                guard  let res: Any = result, let folders: GTLRDrive_FileList = res as? GTLRDrive_FileList, error == nil  else {
                    print("Error of finding folder with name \(folderName) on google drive")
                    self.serviceError = error
                    continuation.resume(returning: nil)
                    return
                }
                guard let identifier: String = folders.files?.first?.identifier, let name = folders.files?.first?.name, name == folderName  else {
                    self.serviceError = error
                    continuation.resume(returning: nil)
                    return
                }
                let canEdit: Bool = folders.files?.first?.capabilities?.canEdit.map({ $0.boolValue }) ?? false
                continuation.resume(returning: RemoteFolderItem(id: identifier, name: name, source: .googledrive, canEdit: canEdit))
            }
        }
    }
    
    func searchFolderWithParent(foldersName: [String]) async throws -> RemoteFolderItem {
        var currentFolderItem: RemoteFolderItem?
        self.serviceError = nil
        guard let firstFolderName: String = foldersName.first  else {
            throw NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Empty root folder."])
        }
       
        guard let firstFolder: RemoteFolderItem = await self.searchChildRootFolder(folderName: firstFolderName) else {
            if let err: Error = self.serviceError {
                throw err
            }
            else {
                throw NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Root folder with name \(firstFolderName) has not been found."])
            }
        }
        currentFolderItem = firstFolder
        for index: Int in 1..<foldersName.count {
            guard let currentFolder: RemoteFolderItem = currentFolderItem, let res: RemoteFolderItem = await searchFolderWithParent(folderName: foldersName[index], parentID: currentFolder.id) else {
                if let err: Error = self.serviceError {
                    throw err
                }
                else {
                    throw NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Folder with name \(foldersName[index]) has not been found."])
                }
            }
            currentFolderItem = res
        }
        var tempName: String = String()
        for itemName: String in foldersName {
            tempName = tempName + itemName + "/"
        }
        tempName.removeLast()
        guard let finalItem = currentFolderItem else {
           throw NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Remote folders have not been found."])
        }
        finalItem.name = tempName
        return finalItem
    }
    
    
    func searchAllFolder() async throws -> Dictionary<String, String> {
        self.serviceError = nil
        var dictionary = Dictionary<String,String>()
        let query1: GTLRDriveQuery_FilesList = GTLRDriveQuery_FilesList.query()
        query1.supportsAllDrives = true
        query1.spaces = "drive"
        query1.q = "mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query1) { (ticket, result, error) in
                guard  let res: Any = result, let folders: GTLRDrive_FileList = res as? GTLRDrive_FileList, error == nil  else {
                    print("Error of finding folders on google drive")
                        self.serviceError = error
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: dictionary)
                    }
                    return
                }
                if let files: [GTLRDrive_File] = folders.files {
                    for driveFile: GTLRDrive_File in files {
                        if let fileIdentifier: String = driveFile.identifier, let fileName: String = driveFile.name {
                            print("folderName: \(fileName), folderId: \(fileIdentifier)")
                            if  let date: Date = driveFile.createdTime?.date {
                                print(" Date of creation: \(date)")
                            }
                            dictionary.updateValue(fileName, forKey: fileIdentifier)
                            if let parents: [String] = driveFile.parents {
                                for parentFolder: String in parents {
                                    print("\(parentFolder) \n")
                                }
                            }
                        }
                    }
                }
                continuation.resume(returning: dictionary)
            }
        }
    }
    
    private func searchAllRootFolder() async throws -> [RemoteFolderItem] {
        self.serviceError = nil
        var dictionary = [RemoteFolderItem]()
        let query1: GTLRDriveQuery_FilesList = GTLRDriveQuery_FilesList.query()
        query1.fields = "files(id,name,capabilities(canEdit))"
        query1.supportsAllDrives = true
        query1.spaces = "drive"
        query1.q = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and ('root' in parents or sharedWithMe = true)"
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query1) { (ticket, result, error) in
                guard  let res: Any = result, let folders: GTLRDrive_FileList = res as? GTLRDrive_FileList, error == nil  else {
                    print("Error of finding folders on google drive")
                        self.serviceError = error
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        let err: Error = NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Children Folders of root folder has not been found."])
                        continuation.resume(throwing: err)
                    }
                    return
                }
                if let files: [GTLRDrive_File] = folders.files {
                    for driveFile: GTLRDrive_File in files {
                        if let fileIdentifier: String = driveFile.identifier,
                           let fileName: String = driveFile.name {
                            let canEdit: Bool = driveFile.capabilities?.canEdit.map({ $0.boolValue }) ?? false
                            print("folderName: \(fileName), folderId: \(fileIdentifier), canEdit \(canEdit)")
                            if  let date: Date = driveFile.createdTime?.date {
                                print(" Date of creation: \(date)")
                            }
                            dictionary.append(RemoteFolderItem(id: fileIdentifier,
                                                               name: fileName,
                                                               source: FolderSource.googledrive,
                                                               canEdit: canEdit,
                                                               children: [RemoteFolderItem]()))
                        }
                    }
                }
                continuation.resume(returning: dictionary)
            }
        }
    }
    
    private func searchChildFolders(parentId: String, parentName: String) async throws-> [RemoteFolderItem] {
        self.serviceError = nil
        var array = [RemoteFolderItem]()
        let query1: GTLRDriveQuery_FilesList = GTLRDriveQuery_FilesList.query()
        query1.fields = "files(id,name,capabilities(canEdit))"
        query1.supportsAllDrives = true
        query1.spaces = "drive"
        query1.q = "mimeType = 'application/vnd.google-apps.folder' and trashed = false and '\(parentId)' in parents"
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query1) { (ticket, result, error) in
                guard  let res: Any = result, let folders: GTLRDrive_FileList = res as? GTLRDrive_FileList, error == nil  else {
                    print("Error of finding children folders of parent folder \(parentName) on google drive")
                    self.serviceError = error
                    if let err = error {
                        continuation.resume(throwing: err)
                    } else {
                        let err: Error = NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Children Folders of parent folder with name \(parentName) has not been found."])
                        continuation.resume(throwing: err)
                    }
                    return
                }
                if let files: [GTLRDrive_File] = folders.files {
                    for driveFile: GTLRDrive_File in files {
                        if let fileIdentifier: String = driveFile.identifier, let fileName: String = driveFile.name {
                            let canEdit: Bool = driveFile.capabilities?.canEdit.map({ $0.boolValue }) ?? false
                            print("folderName: \(fileName), folderId: \(fileIdentifier), canEdit: \(canEdit)")
                            if  let date: Date = driveFile.createdTime?.date {
                                print(" Date of creation: \(date)")
                            }
                            array.append(RemoteFolderItem(id: fileIdentifier,
                                                          name: fileName,
                                                          source: FolderSource.googledrive,
                                                          canEdit: canEdit,
                                                          children: [RemoteFolderItem]()))
                        }
                    }
                }
                continuation.resume(returning: array)
            }
        }
    }
    
    private func searchChildFolders(parent: RemoteFolderItem) async throws {
        let children: [RemoteFolderItem] = try await self.searchChildFolders(parentId: parent.id, parentName: parent.name)
        if children.isEmpty {
            return
        }
        let sortedChildren:[RemoteFolderItem] = children.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        for childFolder: RemoteFolderItem in sortedChildren {
            try await searchChildFolders(parent: childFolder)
        }
        parent.children = sortedChildren
    }
    
    func searchAllFodersWithParents() async throws-> [RemoteFolderItem] {
        let roots: [RemoteFolderItem] = try await self.searchAllRootFolder()
        let sortedRoot:[RemoteFolderItem] = roots.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        for childFolder: RemoteFolderItem in sortedRoot {
            try await self.searchChildFolders(parent: childFolder)
        }
        return sortedRoot
    }
    
    func searchRootFodersWithOutChild() async throws-> [RemoteFolderItem] {
        let roots: [RemoteFolderItem] = try await self.searchAllRootFolder()
        let sortedRoot:[RemoteFolderItem] = roots.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        return sortedRoot
    }
    
    func searchFirstChildFolders(_ parent: RemoteFolderItem) async throws {
        let children: [RemoteFolderItem] = try await self.searchChildFolders(parentId: parent.id, parentName: parent.name)
        if children.isEmpty {
            return
        }
        let sortedChildren:[RemoteFolderItem] = children.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        
        parent.children = sortedChildren
    }
    
    func createFolder(folderName: String, parentFolderId: String) async throws -> (String, String) {
        let folder: GTLRDrive_File = GTLRDrive_File()
        folder.name = folderName
        if parentFolderId.isEmpty == false {
            folder.parents = [parentFolderId]
        }
        folder.mimeType = "application/vnd.google-apps.folder"
        let query1: GTLRDriveQuery_FilesCreate = GTLRDriveQuery_FilesCreate.query(withObject: folder, uploadParameters: nil)
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query1) { (ticket, result, error) in
                guard  let res: Any = result, let folder: GTLRDrive_File = res as? GTLRDrive_File, error == nil  else {
                    print("Error of creating folder with name \(folderName) on google drive")
                    if let err: Error = error {
                        continuation.resume(throwing: err)
                    } else {
                        let err: Error = NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Error of creating folder with name \(folderName)."])
                        continuation.resume(throwing: err)
                    }
                    return
                }
                guard let folderId: String = folder.identifier, let name: String = folder.name, folderName == name else {
                    let err: Error = NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Error of creating folder with name \(folderName)."])
                    continuation.resume(throwing: err)
                    return
                }
                continuation.resume(returning: (folderId, name))
            }
        }
    }
    
    func uploadFile(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        if let remoteId: String = sendigPhoto.remoteIdentifier {
            do {
                let _: String = try await self.searchFileInParent(fileID: remoteId)
                return try await self.updateFileName(sendigPhoto: sendigPhoto)
            } catch {
                return try await self.uploadPhotoProperty(sendigPhoto: sendigPhoto)
            }
        } else {
            return try await self.uploadPhotoProperty(sendigPhoto: sendigPhoto)
        }
    }
    
    private func uploadPhotoProperty(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        let remotesDict: [String: String] = try await self.searchFileInParent(fileName: sendigPhoto.photoName, parentID: sendigPhoto.remoteAlbumIdentifier, mimeType: "image")
        
        let file:GTLRDrive_File = GTLRDrive_File()
        var ind: Int = 0
        let fileName: String = chooseFileName(nextName: sendigPhoto.photoName,originalName: sendigPhoto.photoName, namesList: Array<String>(remotesDict.values), ind: &ind)
        file.name = "\(fileName).jpeg"
        file.parents = [sendigPhoto.remoteAlbumIdentifier]
        let uploadParameters = GTLRUploadParameters(data: sendigPhoto.image, mimeType: "image/jpeg")
        let query: GTLRDriveQuery_FilesCreate = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query) {(ticket: GTLRServiceTicket, result: Any?, error: Error?) in
                guard  let res: Any = result, let file: GTLRDrive_File = res as? GTLRDrive_File, error == nil  else {
                    print("Error of uploading file with name \(sendigPhoto.photoName) into folder \(sendigPhoto.remoteAlbumIdentifier) on google drive")
                    var err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigPhoto.photoName) on session id \(sendigPhoto.sessionId)"])
                    if let execErr: Error = error {
                        err = execErr
                    }
                    continuation.resume(throwing: err)
                    return
                }
                guard let remoteFileId: String = file.identifier, let remoteName: String = file.name else {
                    print("Error of uploading file with name \(sendigPhoto.photoName) on google drive")
                    let err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigPhoto.photoName) on session id \(sendigPhoto.sessionId)"])
                    continuation.resume(throwing: err)
                    return
                }
                let correctedName: String = removeFileExtension(fileName: remoteName)
                let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigPhoto.id, photoName: sendigPhoto.photoName, albumIdentifier: sendigPhoto.albumIdentifier, remoteId: remoteFileId, remoteName: correctedName, remoteAlbumIdentifier: sendigPhoto.remoteAlbumIdentifier, sessionId: sendigPhoto.sessionId)
                continuation.resume(returning: sync)
            }
        }
    }
    
    func uploadFile(sendigMessage: SentMessageProperties) async throws -> SyncPhotosProperties {
        if let remoteId: String = sendigMessage.remoteIdentifier {
            do {
                let _: String = try await self.searchFileInParent(fileID: remoteId)
                return try await self.updateFileName(sendigMessage: sendigMessage)
            } catch {
                return try await self.uploadMessageProperty(sendigMessage: sendigMessage)
            }
        } else {
            return try await self.uploadMessageProperty(sendigMessage: sendigMessage)
        }
    }
    
    private func uploadMessageProperty(sendigMessage: SentMessageProperties) async throws -> SyncPhotosProperties {
        let file:GTLRDrive_File = GTLRDrive_File()
        file.name = "\(sendigMessage.messageName).txt"
        file.parents = [sendigMessage.remoteAlbumIdentifier]
        let uploadParameters = GTLRUploadParameters(data: sendigMessage.text, mimeType: "text/plain")
        let query: GTLRDriveQuery_FilesCreate = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query) {(ticket: GTLRServiceTicket, result: Any?, error: Error?) in
                guard  let res: Any = result, let file: GTLRDrive_File = res as? GTLRDrive_File, error == nil  else {
                    print("Error of uploading file with name \(sendigMessage.messageName) into folder \(sendigMessage.remoteAlbumIdentifier) on google drive")
                    var err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigMessage.messageName) on session id \(sendigMessage.sessionId)"])
                    if let execErr: Error = error {
                        err = execErr
                    }
                    continuation.resume(throwing: err)
                    return
                }
                guard let remoteFileId: String = file.identifier, let remoteName: String = file.name else {
                    print("Error of uploading file with name \(sendigMessage.messageName) on google drive")
                    let err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigMessage.messageName) on session id \(sendigMessage.sessionId)"])
                    continuation.resume(throwing: err)
                    return
                }
                let correctedName: String = removeFileExtension(fileName: remoteName)
                let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigMessage.id, photoName: sendigMessage.messageName, albumIdentifier: sendigMessage.albumIdentifier, remoteId: remoteFileId, remoteName: correctedName, remoteAlbumIdentifier: sendigMessage.remoteAlbumIdentifier, sessionId: sendigMessage.sessionId)
                continuation.resume(returning: sync)
            }
        }
    }
    
    private func searchFileInParent(fileName: String, parentID: String, mimeType: String) async throws -> [String:String] {
        self.serviceError = nil
        var array = [String:String]()
        let query1: GTLRDriveQuery_FilesList = GTLRDriveQuery_FilesList.query()
        query1.fields = "files(id,name,mimeType)"
        query1.supportsAllDrives = true
        query1.spaces = "drive"
        query1.q = "name contains '\(fileName)' and mimeType contains '\(mimeType)' and '\(parentID)' in parents"
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query1) { (ticket, result, error) in
                guard  let res: Any = result, let folders: GTLRDrive_FileList = res as? GTLRDrive_FileList, error == nil  else {
                    print("Error of finding files in parent folder \(fileName) on google drive")
                    self.serviceError = error
                    if let err = error {
                        continuation.resume(throwing: err)
                    } else {
                        let err: Error = NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Children files of parent folder with name \(fileName) has not been found."])
                        continuation.resume(throwing: err)
                    }
                    return
                }
                if let files: [GTLRDrive_File] = folders.files {
                    for driveFile: GTLRDrive_File in files {
                        if let fileIdentifier: String = driveFile.identifier, let remoteName: String = driveFile.name, let mimeType: String = driveFile.mimeType, mimeType.hasPrefix(mimeType) {
                            if fileNameSuffix(name: fileName, fullName: remoteName) {
                                let newName = removeFileExtension(fileName: remoteName)
                                array.updateValue(newName, forKey: fileIdentifier)
                            }
                        }
                    }
                }
                continuation.resume(returning: array)
            }
        }
    }
    
    private func searchFileInParent(fileID: String) async throws -> String {
        self.serviceError = nil
        let query: GTLRDriveQuery_FilesGet = GTLRDriveQuery_FilesGet.query(withFileId: fileID)
        query.fields = "name"
        query.supportsAllDrives = true
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query) { (ticket, result, error) in
                if let err = error {
                    continuation.resume(throwing: err)
                } else {
                    if let res: Any = result, let file: GTLRDrive_File = res as? GTLRDrive_File, let name: String = file.name {
                        continuation.resume(returning: name)
                    } else {
                        let err: Error = NSError(domain: "Google sync module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "File of parent has not been found."])
                        continuation.resume(throwing: err)
                    }
                }
            }
        }
    }
    
    private func updateFileName(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        guard let remoteFileId: String = sendigPhoto.remoteIdentifier else {
            let err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of updating file with name \(sendigPhoto.photoName) on session id \(sendigPhoto.sessionId). The remote Id is empty"])
            throw err
        }
        let remotesDict: [String: String] = try await self.searchFileInParent(fileName: sendigPhoto.photoName, parentID: sendigPhoto.remoteAlbumIdentifier, mimeType: "image")
        
        let file:GTLRDrive_File = GTLRDrive_File()
        var ind: Int = 0
        let fileName: String = chooseFileName(nextName: sendigPhoto.photoName, originalName: sendigPhoto.photoName, namesList: Array<String>(remotesDict.values), ind: &ind)
        file.name = "\(fileName).jpeg"
       
        let query: GTLRDriveQuery_FilesUpdate = GTLRDriveQuery_FilesUpdate.query(withObject: file, fileId: remoteFileId, uploadParameters: nil)
        query.supportsAllDrives = true
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query) {(ticket: GTLRServiceTicket, result: Any?, error: Error?) in
                guard  let res: Any = result, let file: GTLRDrive_File = res as? GTLRDrive_File, error == nil  else {
                    print("Error of uploading file with name \(sendigPhoto.photoName) into folder \(sendigPhoto.remoteAlbumIdentifier) on google drive")
                    var err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigPhoto.photoName) on session id \(sendigPhoto.sessionId)"])
                    if let execErr: Error = error {
                        err = execErr
                    }
                    continuation.resume(throwing: err)
                    return
                }
                guard let remoteFileId: String = file.identifier, let remoteName: String = file.name else {
                    print("Error of uploading file with name \(sendigPhoto.photoName) on google drive")
                    let err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigPhoto.photoName) on session id \(sendigPhoto.sessionId)"])
                    continuation.resume(throwing: err)
                    return
                }
                let correctedName: String = removeFileExtension(fileName: remoteName)
                let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigPhoto.id, photoName: sendigPhoto.photoName, albumIdentifier: sendigPhoto.albumIdentifier, remoteId: remoteFileId, remoteName: correctedName, remoteAlbumIdentifier: sendigPhoto.remoteAlbumIdentifier, sessionId: sendigPhoto.sessionId)
                continuation.resume(returning: sync)
            }
        }
    }
    
    private func updateFileName(sendigMessage: SentMessageProperties) async throws -> SyncPhotosProperties {
        guard let remoteFileId: String = sendigMessage.remoteIdentifier else {
            let err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of updating file with name \(sendigMessage.messageName) on session id \(sendigMessage.sessionId). The remote Id is empty"])
            throw err
        }
        let file: GTLRDrive_File = GTLRDrive_File()
        file.name = "\(sendigMessage.messageName).txt"
        let uploadParameters = GTLRUploadParameters(data: sendigMessage.text, mimeType: "text/plain")
        let query: GTLRDriveQuery_FilesUpdate = GTLRDriveQuery_FilesUpdate.query(withObject: file, fileId: remoteFileId, uploadParameters: uploadParameters)
        query.supportsAllDrives = true
        return try await withCheckedThrowingContinuation { continuation in
            self.googleDriveService.executeQuery(query) {(ticket: GTLRServiceTicket, result: Any?, error: Error?) in
                guard  let res: Any = result, let file: GTLRDrive_File = res as? GTLRDrive_File, error == nil  else {
                    print("Error of uploading file with name \(sendigMessage.messageName) into folder \(sendigMessage.remoteAlbumIdentifier) on google drive")
                    var err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigMessage.messageName) on session id \(sendigMessage.sessionId)"])
                    if let execErr: Error = error {
                        err = execErr
                    }
                    continuation.resume(throwing: err)
                    return
                }
                guard let remoteFileId: String = file.identifier, let remoteName: String = file.name else {
                    print("Error of uploading file with name \(sendigMessage.messageName) on google drive")
                    let err: Error = NSError(domain: "Google Service", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Error of uploading file with name \(sendigMessage.messageName) on session id \(sendigMessage.sessionId)"])
                    continuation.resume(throwing: err)
                    return
                }
                let correctedName: String = removeFileExtension(fileName: remoteName)
                let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigMessage.id, photoName: sendigMessage.messageName, albumIdentifier: sendigMessage.albumIdentifier, remoteId: remoteFileId, remoteName: correctedName, remoteAlbumIdentifier: sendigMessage.remoteAlbumIdentifier, sessionId: sendigMessage.sessionId)
                continuation.resume(returning: sync)
            }
        }
    }
    
    private func chooseFileName(nextName: String, originalName: String, namesList:[String], ind: inout Int) -> String {
        guard let _: String = namesList.first(where: { (item: String) in
            return item == nextName
        }) else {
            return nextName
        }
        ind += 1
        let newName: String = "\(originalName)(\(ind))"
        return chooseFileName(nextName: newName, originalName:originalName, namesList: namesList, ind: &ind)
    }
}

