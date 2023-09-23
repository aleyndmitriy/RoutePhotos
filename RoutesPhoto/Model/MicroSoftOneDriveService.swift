//
//  MicroSoftOneDriveService.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 10.11.2022.
//

import UIKit

class MicroSoftOneDriveService: NSObject {
    private var token: String?
    var components: URLComponents = URLComponents()
    override init() {
        components.scheme = "https"
        components.host = "graph.microsoft.com"
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        super.init()
    }
    
    func setCurrentToken(token: String) {
        self.token = token
    }
    
    func searchAllFodersWithParents() async throws-> [RemoteFolderItem] {
       
        var roots: [RemoteFolderItem] = try await self.getOneDriveFolders(driveId: String(), parentId: String())
        let sharedRoot: [RemoteFolderItem] = try await self.getSharedOneDriveFolders()
        roots.append(contentsOf: sharedRoot)
        let sortedRoots: [RemoteFolderItem] = roots.sorted { (lhs:RemoteFolderItem, rhs: RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        for childFolder: RemoteFolderItem in sortedRoots {
            try await self.searchChildFolders(parent: childFolder)
        }
        return sortedRoots
    }
    
    func searchRootFodersWithOutChild() async throws-> [RemoteFolderItem] {
        var roots: [RemoteFolderItem] = try await self.getOneDriveFolders(driveId: String(), parentId: String())
        let sharedRoot: [RemoteFolderItem] = try await self.getSharedOneDriveFolders()
        roots.append(contentsOf: sharedRoot)
        let sortedRoots: [RemoteFolderItem] = roots.sorted { (lhs:RemoteFolderItem, rhs: RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        return sortedRoots
    }
    
    func searchFirstChildFolders(_ parent: RemoteFolderItem) async throws {
        let children: [RemoteFolderItem] = try await self.getOneDriveFolders(driveId: parent.driveId, parentId: parent.id)
        if children.isEmpty {
            return
        }
        let sortedChildren:[RemoteFolderItem] = children.sorted { (lhs: RemoteFolderItem, rhs:RemoteFolderItem) in
            return lhs.name.lowercased() <= rhs.name.lowercased()
        }
        parent.children = sortedChildren
    }
    
    private func getOneDriveFolders(driveId: String, parentId: String) async throws -> [RemoteFolderItem] {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        if driveId.isEmpty {
            if parentId.isEmpty {
                components.path = "/v1.0/me/drive/root/children"
            } else {
                components.path = "/v1.0/me/drive/items/\(parentId)/children"
            }
        } else {
            components.path = "/v1.0/me/drives/\(driveId)/items/\(parentId)/children"
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "name,id"),
            URLQueryItem(name: "filter", value: "folder ne null")
        ]
        print(components.description)
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "GET"
            let result = try await URLSession.shared.data(for: request)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, response.statusCode == 200 else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let dictionary: Dictionary<String,String> = try self.processJson(json: jsonDictionary)
            var folders = [RemoteFolderItem]()
            for (key,val) in dictionary {
                folders.append(RemoteFolderItem(id: key, name: val, driveId: driveId, source: FolderSource.onedrive, canEdit: true, children: [RemoteFolderItem]()))
            }
            return folders
        } catch {
            throw error
        }
    }
    
    private func searchChildFolders(parent: RemoteFolderItem) async throws {
        let children: [RemoteFolderItem] = try await self.getOneDriveFolders(driveId: parent.driveId, parentId: parent.id)
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
    
    private func processJson(json: [String:Any]) throws -> Dictionary<String,String> {
        guard let verifiedJsonValue = json["value"] as? [[String: Any]] else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json for value."])
            throw err
        }
        var dict = Dictionary<String,String>()
        for dictionaryValues: [String: Any] in verifiedJsonValue {
            do {
                let result = try self.jsonDictionary(dict: dictionaryValues)
                dict.updateValue(result.1, forKey: result.0)
            } catch {
                throw error
            }
        }
        
        return dict
    }
    
    private func getSharedOneDriveFolders() async throws -> [RemoteFolderItem] {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        components.path = "/v1.0/me/drive/sharedWithMe"
        components.queryItems = [
            URLQueryItem(name: "select", value: "remoteItem"),
        ]
        
        print(components.description)
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "GET"
            let result = try await URLSession.shared.data(for: request)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, response.statusCode == 200 else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any], let verifiedJsonValue = jsonDictionary["value"] as? [[String: Any]] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            var folders = [RemoteFolderItem]()
            for dictionaryValues: [String: Any] in verifiedJsonValue {
                guard let remoteItemAny: Any = dictionaryValues["remoteItem"], let remoteItemDict: [String: Any] = remoteItemAny as? [String: Any] else {
                    let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json for id folder."])
                    throw err
                }
                if let _: Any = remoteItemDict["folder"] {
                    guard let remoteReferenceAny: Any = remoteItemDict["parentReference"], let parentReference: [String: Any] = remoteReferenceAny as? [String: Any], let driveIdAny: Any = parentReference["driveId"], let driveId: String = driveIdAny as? String else {
                        let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json for id folder."])
                        throw err
                    }
                    guard let folderIdAny: Any = remoteItemDict["id"] , let folderId: String = folderIdAny as? String else {
                        let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json for id folder."])
                        throw err
                    }
                    guard let folderNameAny: Any = remoteItemDict["name"] , let folderName: String = folderNameAny as? String else {
                        let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json for name folder."])
                        throw err
                    }
                    folders.append(RemoteFolderItem(id: folderId, name: folderName, driveId: driveId, source: FolderSource.onedrive, canEdit: true, children: [RemoteFolderItem]()))
                }
            }
            return folders
            
        } catch {
            throw error
        }
    }
    
    private func jsonDictionary(dict: [String: Any]) throws -> (String,String) {
        guard let folderIdAny: Any = dict["id"] , let folderId: String = folderIdAny as? String else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json for id folder."])
            throw err
        }
        guard let folderNameAny: Any = dict["name"] , let folderName: String = folderNameAny as? String else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json for name folder."])
            throw err
        }
        return (folderId,folderName)
    }
    
    func uploadFile(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        if let remoteId: String = sendigPhoto.remoteIdentifier {
            do {
                let name: String = try await self.searchFileInParent(remoteId: remoteId, parentId: sendigPhoto.remoteAlbumIdentifier, driveId: sendigPhoto.remoteDriveId)
                return try await self.updateFileName(sendigPhoto: sendigPhoto)
            } catch {
                return try await self.uploadPhotoProperty(sendigPhoto: sendigPhoto)
            }
        } else {
            return try await self.uploadPhotoProperty(sendigPhoto: sendigPhoto)
        }
    }
    
    private func uploadPhotoProperty(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        let temporaryName: String = sendigPhoto.photoName.replacingOccurrences(of: ":", with: "_")
        /*let remotesDict: [String: String] = try await self.searchFileInParent(fileName: temporaryName, parentId: sendigPhoto.remoteAlbumIdentifier, driveId: sendigPhoto.remoteDriveId, isImage: true)
        var newFileName: String = temporaryName
        if remotesDict.isEmpty == false {
            newFileName = "\(temporaryName)(\(remotesDict.count))"
            if let _ = remotesDict.first(where: { (key: String, value: String) in
                value == newFileName
            }){
                newFileName = "\(temporaryName)(\(remotesDict.count + 1))"
            }
        }*/
        
        if let driveId: String = sendigPhoto.remoteDriveId {
            components.path = "/v1.0/me/drives/\(driveId)/items/\(sendigPhoto.remoteAlbumIdentifier):/\(temporaryName).jpeg:/content"
        } else {
            components.path = "/v1.0/me/drive/items/\(sendigPhoto.remoteAlbumIdentifier):/\(temporaryName).jpeg:/content"
        }
        components.queryItems = [
            URLQueryItem(name: "@microsoft.graph.conflictBehavior", value: "rename")
        ]
        print(components.description)
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            request.httpMethod = "PUT"
            request.httpBody = sendigPhoto.image
            let result = try await URLSession.shared.upload(for: request, from: sendigPhoto.image)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, (response.statusCode == 201 || response.statusCode == 200) else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let res = try self.jsonDictionary(dict: jsonDictionary)
            let correctedName: String = removeFileExtension(fileName: res.1)
            let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigPhoto.id, photoName: sendigPhoto.photoName, albumIdentifier: sendigPhoto.albumIdentifier, remoteId: res.0, remoteName: correctedName, remoteAlbumIdentifier: sendigPhoto.remoteAlbumIdentifier, sessionId: sendigPhoto.sessionId)
            return sync
        } catch {
            throw error
        }
    }
    
    private func searchFileInParent(remoteId: String, parentId: String, driveId: String?) async throws -> String {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        
        if let drvId: String = driveId {
            components.path = "/v1.0/me/drives/\(drvId)/items/\(parentId)/children"
        } else {
            components.path = "/v1.0/me/drive/items/\(parentId)/children"
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "name,id"),
            URLQueryItem(name: "filter", value: "file ne null and id eq '\(remoteId)'")
        ]
        print(components.description)
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "GET"
            let result = try await URLSession.shared.data(for: request)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, response.statusCode == 200 else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let dictionary: Dictionary<String,String> = try self.processJson(json: jsonDictionary)
            guard let res = dictionary.first, dictionary.count == 1, res.key == remoteId else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "File with id \(remoteId) has not been found or is not unique."])
                throw err
            }
            let correctedName: String = removeFileExtension(fileName: res.value)
            return correctedName
        } catch {
            throw error
        }
    }
    
    private func searchFileInParent(fileName: String, parentId: String, driveId: String?, isImage: Bool) async throws -> [String:String] {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        if let drvId: String = driveId {
            components.path = "/v1.0/me/drives/\(drvId)/items/\(parentId)/children"
        } else {
            components.path = "/v1.0/me/drive/items/\(parentId)/children"
        }
        var sym: String = "eq"
        if isImage {
            sym = "ne"
        }
        let filter: String = "file ne null and image \(sym) null and startswith(name, '\(fileName)')"
        
        components.queryItems = [
            URLQueryItem(name: "select", value: "name,id"),
            URLQueryItem(name: "filter", value: filter)
        ]
        print(components.description)
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.httpMethod = "GET"
            let result = try await URLSession.shared.data(for: request)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, response.statusCode == 200 else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let dictionary: Dictionary<String,String> = try self.processJson(json: jsonDictionary)
            var files = [String:String]()
            for (key,val) in dictionary {
                if fileNameSuffix(name: fileName, fullName: val) {
                    files.updateValue(val, forKey: key)
                }
            }
            return files
        } catch {
            throw error
        }
    }
    
    private func updateFileName(sendigPhoto: SentPhotosProperties) async throws -> SyncPhotosProperties {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        guard let remoteId: String = sendigPhoto.remoteIdentifier else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Remote Id can not be empty."])
            throw err
        }
        let temporaryName: String = sendigPhoto.photoName.replacingOccurrences(of: ":", with: "_")
        if let driveId: String = sendigPhoto.remoteDriveId {
            components.path = "/v1.0/me/drives/\(driveId)/items/\(remoteId)"
        } else {
            components.path = "/v1.0/me/drive/items/\(remoteId)"
        }
        components.queryItems = nil
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            request.httpMethod = "PATCH"
            let json: [String: Any] = ["name": "\(temporaryName).jpeg"]
            let jsonSend = try JSONSerialization.data(withJSONObject: json)
            request.httpBody = jsonSend
            let result = try await URLSession.shared.upload(for: request, from: jsonSend)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, response.statusCode == 200 else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let res = try self.jsonDictionary(dict: jsonDictionary)
            let correctedName: String = removeFileExtension(fileName: res.1)
            let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigPhoto.id, photoName: sendigPhoto.photoName, albumIdentifier: sendigPhoto.albumIdentifier, remoteId: res.0, remoteName: correctedName, remoteAlbumIdentifier: sendigPhoto.remoteAlbumIdentifier, sessionId: sendigPhoto.sessionId)
            return sync
        } catch {
            throw error
        }
    }
    
    private func updateFileName(sendigMessage: SentMessageProperties) async throws -> SyncPhotosProperties {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        guard let remoteId: String = sendigMessage.remoteIdentifier else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Remote Id can not be empty."])
            throw err
        }
        let temporaryName: String = sendigMessage.messageName.replacingOccurrences(of: ":", with: "_")
        if let driveId: String = sendigMessage.remoteDriveId {
            components.path = "/v1.0/me/drives/\(driveId)/items/\(remoteId)"
        } else {
            components.path = "/v1.0/me/drive/items/\(remoteId)"
        }
        components.queryItems = nil
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            request.httpMethod = "PATCH"
            let json: [String: Any] = ["name": "\(temporaryName).txt"]
            let jsonSend = try JSONSerialization.data(withJSONObject: json)
            request.httpBody = jsonSend
            let result = try await URLSession.shared.upload(for: request, from: jsonSend)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, response.statusCode == 200 else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let res = try self.jsonDictionary(dict: jsonDictionary)
            let correctedName: String = removeFileExtension(fileName: res.1)
            let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigMessage.id, photoName: sendigMessage.messageName, albumIdentifier: sendigMessage.albumIdentifier, remoteId: res.0, remoteName: correctedName, remoteAlbumIdentifier: sendigMessage.remoteAlbumIdentifier, sessionId: sendigMessage.sessionId)
            return sync
        } catch {
            throw error
        }
    }
    
    func uploadFile(sendigMessage: SentMessageProperties) async throws -> SyncPhotosProperties {
        if let remoteId: String = sendigMessage.remoteIdentifier {
            do {
                let name: String = try await self.searchFileInParent(remoteId: remoteId, parentId: sendigMessage.remoteAlbumIdentifier, driveId: sendigMessage.remoteDriveId)
                if name == sendigMessage.messageName {
                    return try await self.uploadMessageProperties(sendigMessage: sendigMessage)
                } else {
                    let syncProperty: SyncPhotosProperties = try await self.updateFileName(sendigMessage: sendigMessage)
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
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        let temporaryName: String = sendigMessage.messageName.replacingOccurrences(of: ":", with: "_")
        if let driveId: String = sendigMessage.remoteDriveId {
            components.path = "/v1.0/me/drives/\(driveId)/items/\(sendigMessage.remoteAlbumIdentifier):/\(temporaryName).txt:/content"
        } else {
            components.path = "/v1.0/me/drive/items/\(sendigMessage.remoteAlbumIdentifier):/\(temporaryName).txt:/content"
        }
        components.queryItems = [
            URLQueryItem(name: "@microsoft.graph.conflictBehavior", value: "replace")
        ]
        print(components.description)
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            request.httpMethod = "PUT"
            request.httpBody = sendigMessage.text
            let result = try await URLSession.shared.upload(for: request, from: sendigMessage.text)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, (response.statusCode == 201 || response.statusCode == 200) else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let res = try self.jsonDictionary(dict: jsonDictionary)
            let correctedName: String = removeFileExtension(fileName: res.1)
            let sync: SyncPhotosProperties = SyncPhotosProperties(id: sendigMessage.id, photoName: sendigMessage.messageName, albumIdentifier: sendigMessage.albumIdentifier, remoteId: res.0, remoteName: correctedName, remoteAlbumIdentifier: sendigMessage.remoteAlbumIdentifier, sessionId: sendigMessage.sessionId)
            return sync
        } catch {
            throw error
        }
    }
    
    func createFolder(driveId: String, parentId: String, folderName: String) async throws -> (String,String) {
        guard let currentToken: String = self.token else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "token is empty."])
            throw err
        }
        if driveId.isEmpty {
            if parentId.isEmpty {
                components.path = "/v1.0/me/drive/root/children"
            } else {
                components.path = "/v1.0/me/drive/items/\(parentId)/children"
            }
        } else {
            components.path = "/v1.0/me/drives/\(driveId)/items/\(parentId)/children"
        }
        components.queryItems = nil
        do {
            let url: URL = try components.asURL()
            var request: URLRequest = URLRequest(url: url)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            let bodyString: Dictionary<String,Any> = ["name": folderName,"folder": Dictionary<String,Any>()]
            let bodyData = try JSONSerialization.data(
                withJSONObject: bodyString,
                options: []
            )
            request.httpBody = bodyData
            let result = try await URLSession.shared.data(for: request)
            guard let response: HTTPURLResponse = result.1 as? HTTPURLResponse, response.statusCode <= 201 else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "response is not correct."])
                throw err
            }
            let jsonData: Any = try JSONSerialization.jsonObject(with:result.0,options: [])
            guard let jsonDictionary: [String:Any] = jsonData as? [String:Any] else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Can't parse json."])
                throw err
            }
            let res = try self.jsonDictionary(dict: jsonDictionary)
            if res.1 == folderName {
                return res
            } else {
                let err: Error = NSError(domain: "OneDrive sync module", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Folder name is not correct."])
                throw err
            }
        } catch {
            throw error
        }
    }
}

