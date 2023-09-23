//
//  SyncAssetDatabaseAccessObject.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 09.09.2022.
//

import UIKit
import SwiftUI

enum FolderSource: Int16, CaseIterable, Identifiable, Codable {
    case googledrive = 0
    case dropbox
    case onedrive
    var id: Self {self}
}

func folderSourceToString(_ source: FolderSource) -> String {
    switch source {
    case .googledrive:
        return "GoogleDrive"
    case .dropbox:
        return "DropBox"
    case .onedrive:
        return "OneDrive"
    }
}
class RemoteFolderItem: Identifiable, Hashable {
   
    var id: String
    var name: String
    var driveId: String
    var folderSource: FolderSource
    var children: [RemoteFolderItem]? = nil
    var expanded: Bool = false
    var level: Int = 0
    let canEdit: Bool
    var folderDescription: String {
        let accessSymbol = canEdit ? "" :"⛔️"
        switch children {
        case nil:
            return "📄\(accessSymbol) \(name)"
        case .some(let children):
            return children.isEmpty ? "📂\(accessSymbol) \(name)" : "📁\(accessSymbol) \(name)"
        }
    }
    
    init(id: String, name: String, driveId: String, source: FolderSource, canEdit: Bool = false, children: [RemoteFolderItem]?) {
        self.id = id
        self.name = name
        self.driveId = driveId
        self.folderSource = source
        self.children = children
        self.canEdit = canEdit
    }
    
    convenience init(id: String, name: String, source: FolderSource, canEdit: Bool = false, children: [RemoteFolderItem]?) {
        self.init(id: id, name: name, driveId: String(), source: source, canEdit: canEdit, children: children)
    }
    
    convenience init(id: String, name: String, source: FolderSource, canEdit: Bool = false) {
        self.init(id: id, name: name, source: source, canEdit: canEdit, children: nil)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    static func == (lhs: RemoteFolderItem, rhs: RemoteFolderItem) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
    
    func addChild(_ folderItem: RemoteFolderItem) {
        if children == nil {
            children = [folderItem]
        } else {
            children?.append(folderItem)
        }
    }
    
    func expandedNodesCount() -> Int {
        guard let child: [RemoteFolderItem] = self.children, child.isEmpty == false else {
            return 0
        }
        let count = child.reduce(0, { result, node -> Int in
            return result + 1 + (node.expanded ? node.expandedNodesCount() : 0)
        })
        return count;
    }
}

class FolderItem: Identifiable, Hashable, Codable {
    let id: String
    let localName: String
    let remoteId: String
    let remoteName: String
    let remoteDriveId: String
    let folderSource: FolderSource
    let nonSyncNumber: Int
    let totalNumber: Int
    let order: Int32
    
    init(id: String, localName: String, remoteId: String, remoteName: String, remoteDriveId: String, source: FolderSource, order: Int32, nonSyncNumber: Int, totalNumber: Int) {
        self.id = id
        self.localName = localName
        self.remoteId = remoteId
        self.remoteName = remoteName
        self.remoteDriveId = remoteDriveId
        self.folderSource = source
        self.order = order
        self.nonSyncNumber = nonSyncNumber
        self.totalNumber = totalNumber
    }
    
    convenience init(id: String, localName: String, remoteId: String, remoteName: String, source: FolderSource, order: Int32, nonSyncNumber: Int, totalNumber: Int) {
        self.init(id: id, localName: localName, remoteId: remoteId, remoteName: remoteName, remoteDriveId: String(), source: source, order: order, nonSyncNumber: nonSyncNumber, totalNumber: totalNumber)
    }
    
    convenience init(id: String, localName: String, order: Int32, remoteFolder:RemoteFolderItem) {
        self.init(id:id,localName:localName, remoteId: remoteFolder.id, remoteName:remoteFolder.name, remoteDriveId: remoteFolder.driveId,source: remoteFolder.folderSource, order: order, nonSyncNumber: 0, totalNumber: 0)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(localName)
        hasher.combine(remoteId)
        hasher.combine(remoteName)
    }
    
    static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
        return lhs.id == rhs.id && lhs.localName == rhs.localName && lhs.remoteId == rhs.remoteId && lhs.remoteName == rhs.remoteName
    }
}

class PhotoIdentityItem: Identifiable, Hashable {
    let id: String
    let albumIdentifier: String
    let photoName: String
    let remoteIdentifier: String
    let remoteName: String
    
    init(id: String, albumIdentifier: String, photoName: String, remoteIdentifier: String, remoteName: String) {
        self.id = id
        self.albumIdentifier = albumIdentifier
        self.photoName = photoName
        self.remoteIdentifier = remoteIdentifier
        self.remoteName = remoteName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(photoName)
        hasher.combine(remoteIdentifier)
        hasher.combine(remoteName)
    }
    
    static func == (lhs: PhotoIdentityItem, rhs: PhotoIdentityItem) -> Bool {
        return lhs.id == rhs.id && lhs.photoName == rhs.photoName && lhs.remoteIdentifier == rhs.remoteIdentifier && lhs.remoteName == rhs.remoteName
    }
}


class SyncAssetDatabaseAccessObject: NSObject {
    let database: CoreDataSyncAssetDatabase = CoreDataSyncAssetDatabase.shared
    
    override init() {
        super.init()
    }
    
    func createAlbum(folderItem: FolderItem) async throws {
            try await database.insertIdentityItem(folderItem: folderItem)
    }
    
    func loadAlbums() async throws -> [FolderItem] {
        do {
            let folders: [FolderItem] = try await self.loadIdentities()
            return folders
        } catch {
            throw error
        }
    }
    
    func findAlbum(albumName: String) async throws -> FolderItem? {
        do {
            let result: [AlbumIdentity] = try await database.getIdentitiesItems(albumName: albumName)
            if let albumItem: AlbumIdentity = result.first, let folderItem: FolderItem = self.mapIdentity(album: albumItem) {
               return folderItem
            }
            return nil
        } catch {
            throw error
        }
    }
    
    func findAlbum(albumId: String) async throws -> FolderItem {
        do {
            let result: [AlbumIdentity] = try await database.getIdentitiesItems(albumId: albumId)
            if let albumItem: AlbumIdentity = result.first, let folderItem: FolderItem = self.mapIdentity(album: albumItem) {
               return folderItem
            }
            throw PhotoError.missingData
        } catch {
            throw error
        }
    }
    
    func chekDublicateAlbum(albumName: String) async throws {
        do {
            try await database.checkDublicates(albumName: albumName)
        } catch {
            throw error
        }
    }
    
    func chekDublicateAlbum(remoteId: String, remoteName: String) async throws {
        do {
            try await database.checkDublicates(remoteId: remoteId, remoteName: remoteName)
        } catch {
            throw error
        }
    }
    
    func chekDublicateAlbum(remoteName: String) async throws {
        do {
            try await database.checkDublicates(remoteName: remoteName)
        } catch {
            throw error
        }
    }
    
    func findAlbum(remoteId: String, remoteName: String) async throws -> FolderItem? {
        do {
            let result: [AlbumIdentity] = try await database.getIdentitiesItems(remoteId: remoteId, remoteName: remoteName)
            if let albumItem: AlbumIdentity = result.first, let folderItem: FolderItem = self.mapIdentity(album: albumItem) {
                return folderItem
            }
            return nil
        } catch {
            throw error
        }
    }
    
    func deleteAlbums(localId: String, localName: String) async throws {
            try await database.deleteAlbumIdentity(localId: localId, localName: localName)
    }
    
    func updateAlbums(localId: String, localName: String, storageType: FolderSource, newRemoteId: String, newRemoteName: String, newDriveId: String) async throws {
        try await database.updateAlbumIdentity(localId: localId, albumName: localName, storageType: storageType, newRemoteId: newRemoteId, newRemoteName: newRemoteName, newRemoteDriveId: newDriveId)
    }
    
    func updateAlbums(localId: String, localName: String, newName: String) async throws {
        try await database.updateAlbumIdentity(localId: localId, albumName: localName, newName: newName)
    }
    
    func updateAlbums(localId: String, localName: String, newLocalName: String, storageType: FolderSource, newRemoteId: String, newRemoteName: String, newDriveId: String) async throws {
        try await database.updateAlbumIdentity(localId: localId, albumName: localName, newName: newLocalName, storageType: storageType, newRemoteId: newRemoteId, newRemoteName: newRemoteName, newRemoteDriveId: newDriveId)
    }
    
    private func loadIdentities() async throws -> [FolderItem] {
        let result: [AlbumIdentity] = try await database.getIdentitiesItems()
        let folders: [FolderItem] = self.mapIdentities(identities: result)
        return folders
    }
    
    private func mapIdentities(identities: [AlbumIdentity]) -> [FolderItem] {
        return identities.compactMap { (item: AlbumIdentity) in
            return self.mapIdentity(album: item)
        }
    }
    
    private func mapIdentity(album: AlbumIdentity) -> FolderItem? {
        guard let source: FolderSource = FolderSource(rawValue: album.type) else {
            return nil
        }
        var identifier: String = String()
        if let ident: String = album.remoteFolderIdentifier {
            identifier = ident
        }
        var name: String = String()
        if let remouteName: String = album.remoteFolderName {
            name = remouteName
        }
        var num: Int = 0
        var total: Int = 0
        if let photoIdentities: NSSet = album.photoIdentity, photoIdentities.count > 0 {
            for photoIdentity: Any in photoIdentities {
                if let photo: PhotoIdentity = photoIdentity as? PhotoIdentity, let _: UUID = UUID(uuidString: photo.photoIdentifier)  {
                    total += 1
                    if photo.remoteName == nil {
                           num += 1
                    }
                }
            }
        }
        var driveId: String = String()
        if let coreDriveId: String = album.remoteDriveId {
            driveId = coreDriveId
        }
        return FolderItem(id: album.localIdentifier, localName: album.localizedTitle, remoteId: identifier, remoteName: name, remoteDriveId: driveId, source: source, order: album.order, nonSyncNumber: num, totalNumber: total)
    }
    
}

func createFullPath(remoteId: String, folders: RemoteFolderItem, fullPath: inout String, driveId: inout String) -> Bool {
    if remoteId == folders.id {
        if fullPath.isEmpty {
            fullPath = String(format:"%@",folders.name)
        } else {
            fullPath = String(format: "%@/%@",fullPath,folders.name)
        }
        driveId = folders.driveId
        return true
    }
    guard let childFolders: [RemoteFolderItem] = folders.children, childFolders.isEmpty == false else {
        return false
    }
    for childFolder: RemoteFolderItem in childFolders {
        if createFullPath(remoteId: remoteId, folders: childFolder, fullPath: &fullPath, driveId: &driveId) {
            fullPath = String(format: "%@/%@",folders.name, fullPath)
            driveId = folders.driveId
            return true
        }
    }
    return false
}

//func traverseThroughExpanded(_ parent: RemoteFolderItem)
