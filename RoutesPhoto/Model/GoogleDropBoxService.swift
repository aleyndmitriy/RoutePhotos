//
//  GoogleDropBoxService.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 28.10.2022.
//

import UIKit
import SwiftyDropbox

class GoogleDropBoxService: NSObject {
    var client: DropboxClient?
    public static let appKey: String = "5sfk3cxab4pxfn3"
    private var dropBoxQueue = DispatchQueue(label: "dropBoxQueue", attributes: .concurrent)
    override init() {
        super.init()
    }
    
    
    private func getDropBoxFoldersMetaData(parentId: String) async throws -> Files.ListFolderResult {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
        return try await withCheckedThrowingContinuation { continuation in
            dropBoxClient.files.listFolder(path: parentId, recursive: false, includeMediaInfo: false, includeDeleted: false, includeHasExplicitSharedMembers: true, includeMountedFolders: true, limit: nil, sharedLink: nil, includePropertyGroups: nil, includeNonDownloadableFiles: false).response(queue: self.dropBoxQueue) {(result, error ) in
                if let data = result, error == nil{
                    continuation.resume(returning: data)
                }
                if let err: CallError<Files.ListFolderError> = error {
                    let str: String = err.description
                    let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                    continuation.resume(throwing: resError)
                }
            }
        }
    }
    
    private func getDropBoxFoldersMetaDataContinue(cursor: String) async throws -> Files.ListFolderResult {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
        return try await withCheckedThrowingContinuation { continuation in
            dropBoxClient.files.listFolderContinue(cursor:cursor).response(queue: self.dropBoxQueue) {(result, error ) in
                if let data = result, error == nil{
                    continuation.resume(returning: data)
                }
                if let err: CallError<Files.ListFolderContinueError> = error {
                    let str: String = err.description
                    let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                    continuation.resume(throwing: resError)
                }
            }
        }
    }
    
   
    
    func getDropBoxFolders(parentId: String) async throws -> [RemoteFolderItem] {
        var folders = [RemoteFolderItem]()
        var temporaryResult: Files.ListFolderResult = try await getDropBoxFoldersMetaData(parentId: parentId)
        var hasMore: Bool = true
        while(hasMore) {
            let temporaryFolders: [RemoteFolderItem] = temporaryResult.entries.compactMap({ (metadata:Files.Metadata) in
                if let folder: Files.FolderMetadata = metadata as? Files.FolderMetadata {
                    return RemoteFolderItem(id: folder.id, name: folder.name, source: FolderSource.dropbox,canEdit: true,children:[RemoteFolderItem]())
                } else {
                    return nil
                }
            })
            folders.append(contentsOf: temporaryFolders)
            hasMore = temporaryResult.hasMore
            if hasMore == false {
                return folders
            }
            temporaryResult = try await getDropBoxFoldersMetaDataContinue(cursor: temporaryResult.cursor)
        }
        return folders
    }
    
    private func searchChildFolders(parent: RemoteFolderItem) async throws {
        let children: [RemoteFolderItem] = try await self.getDropBoxFolders(parentId: parent.id)
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
        let roots: [RemoteFolderItem] = try await self.getDropBoxFolders(parentId:"")
        let sortedRoot:[RemoteFolderItem] = roots.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        for childFolder: RemoteFolderItem in sortedRoot {
            try await self.searchChildFolders(parent: childFolder)
        }
        return sortedRoot
    }
    
    func searchRootFodersWithOutChild() async throws-> [RemoteFolderItem] {
        let roots: [RemoteFolderItem] = try await self.getDropBoxFolders(parentId:"")
        let sortedRoot:[RemoteFolderItem] = roots.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        return sortedRoot
    }
    
    func searchFirstChildFolders(_ parent: RemoteFolderItem) async throws {
        let children: [RemoteFolderItem] = try await self.getDropBoxFolders(parentId: parent.id)
        if children.isEmpty {
            return
        }
        let sortedChildren:[RemoteFolderItem] = children.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        parent.children = sortedChildren
    }
    
    func uploadFile(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        if let remoteId: String = sendigPhoto.remoteIdentifier {
            do {
                let name: String = try await self.searchFileInParent(fileID: remoteId)
                return try await self.updateFileName(sendigPhoto: sendigPhoto, oldName: name)
            } catch {
                return try await self.uploadPhotoProperty(sendigPhoto: sendigPhoto)
            }
        } else {
            return try await self.uploadPhotoProperty(sendigPhoto: sendigPhoto)
        }
    }
    
    private func uploadPhotoProperty(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
        return try await withCheckedThrowingContinuation { continuation in
            dropBoxClient.files.upload(path: "\(sendigPhoto.remoteAlbumIdentifier)/\(sendigPhoto.photoName).jpeg", mode: .add, autorename: true, input: sendigPhoto.image).response(queue: self.dropBoxQueue) { (result:Files.FileMetadata?, error:CallError<Files.UploadError>? ) in
                if let data = result, error == nil {
                    let correctedName: String = removeFileExtension(fileName: data.name)
                    let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigPhoto.id, photoName: sendigPhoto.photoName, albumIdentifier: sendigPhoto.albumIdentifier, remoteId: data.id, remoteName: correctedName, remoteAlbumIdentifier: sendigPhoto.remoteAlbumIdentifier, sessionId: sendigPhoto.sessionId)
                    continuation.resume(returning: sync)
                } else {
                    if let err: CallError<Files.UploadError> = error {
                        let str: String = err.description
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                        continuation.resume(throwing: resError)
                    } else {
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "File with name\(sendigPhoto.photoName) has not been uploaded."])
                        continuation.resume(throwing: resError)
                    }
                }
            }
        }
    }
    
    private func searchFileInParent(fileID: String) async throws -> String {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
       
        return try await withCheckedThrowingContinuation { continuation in
            dropBoxClient.files.getMetadata(path: fileID).response(queue: self.dropBoxQueue) { (result: Files.Metadata?, error:CallError<Files.GetMetadataError>?) in
                if let data = result, let fileData: Files.FileMetadata = data as? Files.FileMetadata, error == nil {
                    print(fileData.id)
                    let correctedName: String = removeFileExtension(fileName: fileData.name)
                    continuation.resume(returning: correctedName)
                } else {
                    if let err: CallError<Files.GetMetadataError> = error {
                        let str: String = err.description
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                        continuation.resume(throwing: resError)
                    } else {
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "File with id \(fileID) has not been found"])
                        continuation.resume(throwing: resError)
                    }
                }
            }
        }
    }
    
    private func updateFileName(sendigPhoto: SentPhotosProperties, oldName: String) async throws -> SyncPhotosProperties {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
        return try await withCheckedThrowingContinuation { continuation in
            dropBoxClient.files.moveV2(fromPath: "\(sendigPhoto.remoteAlbumIdentifier)/\(oldName).jpeg", toPath: "\(sendigPhoto.remoteAlbumIdentifier)/\(sendigPhoto.photoName).jpeg").response(queue: self.dropBoxQueue) { (result:Files.RelocationResult?, error: CallError<Files.RelocationError>?) in
                if let data = result, let fileData: Files.FileMetadata = data.metadata as? Files.FileMetadata, error == nil  {
                    
                    print("final id: \(fileData.id), name: \(fileData.name)")
                    let correctedName: String = removeFileExtension(fileName: fileData.name)
                    let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigPhoto.id, photoName: sendigPhoto.photoName, albumIdentifier: sendigPhoto.albumIdentifier, remoteId: fileData.id, remoteName: correctedName, remoteAlbumIdentifier: sendigPhoto.remoteAlbumIdentifier, sessionId: sendigPhoto.sessionId)
                    continuation.resume(returning: sync)
                } else {
                    if let err: CallError<Files.RelocationError> = error {
                        let str: String = err.description
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                        continuation.resume(throwing: resError)
                    } else {
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "File with name\(sendigPhoto.photoName) has not been renamed."])
                        continuation.resume(throwing: resError)
                    }
                }
            }
        }
    }
    
    private func updateFileName(sendigMessage: SentMessageProperties, oldName: String) async throws -> SyncPhotosProperties {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
        return try await withCheckedThrowingContinuation { continuation in
            dropBoxClient.files.moveV2(fromPath: "\(sendigMessage.remoteAlbumIdentifier)/\(oldName).txt", toPath: "\(sendigMessage.remoteAlbumIdentifier)/\(sendigMessage.messageName).txt").response(queue: self.dropBoxQueue) { (result:Files.RelocationResult?, error: CallError<Files.RelocationError>?) in
                if let data = result, let fileData: Files.FileMetadata = data.metadata as? Files.FileMetadata, error == nil  {
                    let correctedName: String = removeFileExtension(fileName: fileData.name)
                    print("final id: \(fileData.id), name: \(fileData.name)")
                    let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigMessage.id, photoName: sendigMessage.messageName, albumIdentifier: sendigMessage.albumIdentifier, remoteId: fileData.id, remoteName: correctedName, remoteAlbumIdentifier: sendigMessage.remoteAlbumIdentifier, sessionId: sendigMessage.sessionId)
                    continuation.resume(returning: sync)
                } else {
                    if let err: CallError<Files.RelocationError> = error {
                        let str: String = err.description
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                        continuation.resume(throwing: resError)
                    } else {
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "File with name\(sendigMessage.messageName) has not been renamed."])
                        continuation.resume(throwing: resError)
                    }
                }
            }
        }
    }

    
    func uploadFile(sendigMessage: SentMessageProperties) async throws -> SyncPhotosProperties {
        if let remoteId: String = sendigMessage.remoteIdentifier {
            do {
                let name: String = try await self.searchFileInParent(fileID: remoteId)
                if name == sendigMessage.messageName {
                    return try await self.uploadMessageProperties(sendigMessage: sendigMessage)
                } else {
                    let syncProperty: SyncPhotosProperties = try await self.updateFileName(sendigMessage: sendigMessage, oldName: name)
                    sendigMessage.remoteIdentifier = syncProperty.remoteId
                    sendigMessage.remoteName = syncProperty.remoteName
                    return try await self.uploadMessageProperties(sendigMessage: sendigMessage)
                }
            } catch {
                return try await self.uploadMessageProperties(sendigMessage: sendigMessage)
            }
        } else {
            return try await self.uploadMessageProperties(sendigMessage: sendigMessage)
        }
    }
    
    private func uploadMessageProperties(sendigMessage: SentMessageProperties) async throws -> SyncPhotosProperties {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
        return try await withCheckedThrowingContinuation { continuation in
            dropBoxClient.files.upload(path: "\(sendigMessage.remoteAlbumIdentifier)/\(sendigMessage.messageName).txt", mode: .overwrite, autorename: false, input: sendigMessage.text).response(queue: self.dropBoxQueue) { (result:Files.FileMetadata?, error:CallError<Files.UploadError>? ) in
                if let data = result, error == nil {
                    let correctedName: String = removeFileExtension(fileName: data.name)
                    let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigMessage.id, photoName: sendigMessage.messageName, albumIdentifier: sendigMessage.albumIdentifier, remoteId: data.id, remoteName: correctedName, remoteAlbumIdentifier: sendigMessage.remoteAlbumIdentifier, sessionId: sendigMessage.sessionId)
                    continuation.resume(returning: sync)
                } else {
                    if let err: CallError<Files.UploadError> = error {
                        let str: String = err.description
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                        continuation.resume(throwing: resError)
                    } else {
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "File with name\(sendigMessage.messageName) has not been uploaded."])
                        continuation.resume(throwing: resError)
                    }
                }
            }
        }
    }
    
    func createFolder(folderName: String, parentFolderId: String) async throws -> (String, String) {
        guard let dropBoxClient: DropboxClient = client else {
            let err: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Client is empty."])
            throw err
        }
        var path = "/\(folderName)"
        if parentFolderId.isEmpty == false {
            path = "/\(parentFolderId)/\(folderName)"
        }
        return try await withCheckedThrowingContinuation {
            continuation in
            dropBoxClient.files.createFolderV2(path: path).response { (result: Files.CreateFolderResult?, error: CallError<Files.CreateFolderError>?) in
                if let data = result, data.metadata.name == folderName, error == nil {
                    continuation.resume(returning: (data.metadata.id, data.metadata.name))
                } else {
                    if let err: CallError<Files.CreateFolderError> = error {
                        let str: String = err.description
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: str])
                        continuation.resume(throwing: resError)
                    } else {
                        let resError: Error = NSError(domain: "DropBox sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Folder with name\(folderName) has not been created."])
                        continuation.resume(throwing: resError)
                    }
                }
            }
        }
    }
}
