//
//  RemoteFolderEditObject.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 12.01.2023.
//

import Foundation


class RemoteFolderEditObject: ObservableObject {
    @Published var remoteFolderId: String = String()
    @Published var remoteFolderPath: String = String()
    @Published var remoteDriveId: String = String()
    @Published var childFolders: [RemoteFolderItem] = [RemoteFolderItem]()
    @Published var oneDimensionalList: [RemoteFolderItem] = [RemoteFolderItem]()
    
    func clear() {
        remoteFolderId = String()
        remoteFolderPath = String()
        remoteDriveId = String()
        childFolders = [RemoteFolderItem]()
        oneDimensionalList = [RemoteFolderItem]()
    }
    
    func processTreeToOneDimentionList() {
        oneDimensionalList = [RemoteFolderItem]()
        for rootItem: RemoteFolderItem in childFolders {
            oneDimensionalList.append(rootItem)
            self.traverseThroughExpanded(rootItem)
        }
    }
    
    private func traverseThroughExpanded(_ item: RemoteFolderItem) {
        if item.expanded {
            if let child: [RemoteFolderItem] = item.children, child.isEmpty == false {
                for secondChild in child {
                    secondChild.level = item.level + 1
                    oneDimensionalList.append(secondChild)
                    traverseThroughExpanded(secondChild)
                }
            }
        }
    }
    
    func expandCell(itemId: String) {
        guard let currentNode: RemoteFolderItem = oneDimensionalList.first(where: { (item: RemoteFolderItem) in
            return item.id == itemId
        }) else {
            return
        }
        currentNode.expanded = true
        self.processTreeToOneDimentionList()
    }
    
    func collapseCell(itemId: String) {
        guard let currentNode: RemoteFolderItem = oneDimensionalList.first(where: { (item: RemoteFolderItem) in
            return item.id == itemId
        }) else {
            return
        }
        currentNode.expanded = false
        self.processTreeToOneDimentionList()
    }
    
    func getFolder(folderId: String) -> RemoteFolderItem? {
        for parentFolder: RemoteFolderItem in childFolders {
            if parentFolder.id == folderId {
                return parentFolder
            }
            if let findingFolder: RemoteFolderItem = self.getChildeFolder(folderId: folderId, folder: parentFolder) {
                return findingFolder
            }
        }
        return nil
    }
    
    private func getChildeFolder(folderId: String, folder: RemoteFolderItem)-> RemoteFolderItem? {
        if folderId == folder.id {
            return folder
        }
        if let child: [RemoteFolderItem] = folder.children, child.isEmpty == false {
            for childFolder: RemoteFolderItem in child {
                if let findingFolder: RemoteFolderItem = getChildeFolder(folderId: folderId, folder: childFolder) {
                    return findingFolder
                }
            }
        }
        return nil
    }
    
    func createRemotePath(selected: String) -> (String, String) {
        var fullPath = String()
        var driveId = String()
        for childFolder: RemoteFolderItem in childFolders {
            if createFullPath(remoteId: selected, folders: childFolder, fullPath: &fullPath, driveId: &driveId) {
                return (fullPath,driveId)
            }
        }
        return (fullPath,driveId)
    }
    
    
}


