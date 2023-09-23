//
//  PhotoLibraryController.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 17.08.2022.
//


let defaultCollectionName: String = "Unsorted"
let defaultAlbumName: String = "UnsortedAlbum"

import Foundation
import Photos
import SwiftUI
import CoreLocation

enum LibraryState: Int {
    case idle = 0
    case loading
    case saving
    case deleting
    case uploading
    case creating
}

class ItemCollection: Identifiable, Hashable {
    let id: String
    let collection: PHCollection
    
    init(name: String, collection: PHCollection) {
        self.id = name
        self.collection = collection
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItemCollection, rhs: ItemCollection) -> Bool {
        return lhs.id == rhs.id
    }
}

class ItemAsset: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    
    init(localIdentifier: String, asset: PHAsset) {
        self.id = localIdentifier
        self.asset = asset
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItemAsset, rhs: ItemAsset) -> Bool {
        return lhs.id == rhs.id
    }
}

class ItemAssetBaseView: Identifiable, Hashable {
    let id: String
    let creationDate: Date
    let latitude: Double
    let longitude: Double
    
    init(localIdentifier: String,creationDate: Date, latitude: Double, longitude: Double) {
        self.id = localIdentifier
        self.creationDate = creationDate
        self.latitude = latitude
        self.longitude = longitude
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItemAssetBaseView, rhs: ItemAssetBaseView) -> Bool {
        return lhs.id == rhs.id
    }
}

class ItemAssetView: ItemAssetBaseView {

    let url: URL
    
    init(localIdentifier: String, url: URL, creationDate: Date, latitude: Double, longitude: Double) {
        self.url = url
        super.init(localIdentifier: localIdentifier, creationDate: creationDate, latitude: latitude, longitude: longitude)
    }
    
    override func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItemAssetView, rhs: ItemAssetView) -> Bool {
        return lhs.id == rhs.id
    }
}

class ItemAssetDataView: ItemAssetBaseView {

    let imgData: Data
    
    init(localIdentifier: String, imgData: Data, creationDate: Date, latitude: Double, longitude: Double) {
        self.imgData = imgData
        super.init(localIdentifier: localIdentifier, creationDate: creationDate, latitude: latitude, longitude: longitude)
    }
    
    override func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItemAssetDataView, rhs: ItemAssetDataView) -> Bool {
        return lhs.id == rhs.id
    }
}

class PhotoLibraryController: NSObject, ObservableObject {
    @Published var userCollections = [ItemCollection]()
    @Published var currentAlbumsCollection = [ItemCollection]()
    @Published var currentAssets = [ItemAsset]()
    @Published var error: Error?
    @Published var isProcessing: Bool = false
    @Published var currentAssetsImage = Set<ItemAssetView>()
    let locationManager: CLLocationManager = CLLocationManager()
    private let concurrentQueue = DispatchQueue(label: "photolibrary.concurrent.queue",qos: .userInitiated, attributes: .concurrent)
    private let imageManager = PHImageManager.default()
    private var imageOptions = PHImageRequestOptions()
    private var libraryState: LibraryState = .idle {
        didSet {
            if libraryState == .idle {
                isProcessing = false
            } else {
                isProcessing = true
            }
        }
    }
    
    
    override init() {
        super.init()
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        self.imageOptions.version = .current
        self.imageOptions.isSynchronous = false
        self.imageOptions.isNetworkAccessAllowed = true
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func loadRootFolders() {
        libraryState = .loading
        self.userCollections.removeAll()
        concurrentQueue.async {
            let options: PHFetchOptions = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true), NSSortDescriptor(key: "startDate", ascending: true)]
            let fetchResult: PHFetchResult<PHCollection> = PHCollectionList.fetchTopLevelUserCollections(with: options)
            var tempCollection: [ItemCollection] = [ItemCollection]()
            fetchResult.enumerateObjects { (collection: PHCollection, _, _ ) in
                if let name: String = collection.localizedTitle {
                    if let listCollection: PHCollectionList = collection as? PHCollectionList {
                        tempCollection.append(ItemCollection(name: name, collection: listCollection))
                    }
                }
            }
            DispatchQueue.main.async {
                if tempCollection.isEmpty == false {
                    self.userCollections.append(contentsOf: tempCollection)
                }
                print("Number \(self.userCollections.count)")
                self.libraryState = .idle
            }
        }
    }
    
    func loadAlbumsInFolder(folderID: String) {
        libraryState = .loading
        self.currentAlbumsCollection.removeAll()
        concurrentQueue.async {
            guard let rootFolder: PHCollectionList = self.userCollections.first(where: { (item: ItemCollection) in
                return item.id == folderID
            })?.collection as? PHCollectionList else {
                print("Error of finding folder with id \(folderID).")
                DispatchQueue.main.async {
                    self.libraryState = .idle
                }
                return
            }
            let options: PHFetchOptions = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true), NSSortDescriptor(key: "startDate", ascending: true)]
            let fetchResult: PHFetchResult<PHCollection> = PHCollectionList.fetchCollections(in: rootFolder, options: options)
            var tempCollection: [ItemCollection] = [ItemCollection]()
            fetchResult.enumerateObjects { (collection: PHCollection, _, _ ) in
                if let albumCollection: PHAssetCollection = collection as? PHAssetCollection {
                    if let name: String = albumCollection.localizedTitle {
                        tempCollection.append(ItemCollection(name: name, collection: albumCollection))
                    }
                }
            }
            DispatchQueue.main.async {
                if tempCollection.isEmpty == false {
                    self.currentAlbumsCollection.append(contentsOf: tempCollection)
                }
                print("Number \(self.currentAlbumsCollection.count)")
                self.libraryState = .idle
            }
        }
    }
    
    func loadAlbumsRootFolder() {
        libraryState = .loading
        self.currentAlbumsCollection.removeAll()
        concurrentQueue.async {
            let options: PHFetchOptions = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true), NSSortDescriptor(key: "startDate", ascending: true)]
            let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
            var tempCollection: [ItemCollection] = [ItemCollection]()
            fetchResult.enumerateObjects { (albumCollection: PHAssetCollection, _, _ ) in
                if let name: String = albumCollection.localizedTitle {
                    tempCollection.append(ItemCollection(name: name, collection: albumCollection))
                }
            }
            DispatchQueue.main.async {
                if tempCollection.isEmpty == false {
                    self.currentAlbumsCollection.append(contentsOf: tempCollection)
                }
                print("Number \(self.currentAlbumsCollection.count)")
                self.libraryState = .idle
            }
        }
    }
    
    
    func loadPhotoInAlbum(albumName: String) {
        libraryState = .loading
        currentAssets.removeAll()
        concurrentQueue.async {
            guard let rootAlbum: PHAssetCollection = self.currentAlbumsCollection.first(where: { (item: ItemCollection) in
                return item.id == albumName
            })?.collection as? PHAssetCollection else {
                print("Error of finding album with name \(albumName).")
                DispatchQueue.main.async {
                    self.libraryState = .idle
                }
                return
            }
            let options: PHFetchOptions = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "mediaType", ascending: true), NSSortDescriptor(key: "creationDate", ascending: true)]
            let fetchResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: rootAlbum, options: options)
            var tempCollection: [ItemAsset] = [ItemAsset]()
            fetchResult.enumerateObjects { (asset: PHAsset, _, _) in
                tempCollection.append(ItemAsset(localIdentifier: asset.localIdentifier, asset: asset))
            }
            DispatchQueue.main.async {
                if tempCollection.isEmpty == false {
                    self.currentAssets.append(contentsOf: tempCollection)
                }
                print("Number of photos \(self.currentAssets.count)")
                
                self.libraryState = .idle
            }
           
        }
    }
    
    func loadAllPhotos() {
        currentAssetsImage.removeAll()
        currentAssets.removeAll()
        isProcessing.toggle()
        concurrentQueue.async {
            let options: PHFetchOptions = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let fetchResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
            print("\(fetchResult.count)")
            var itemAssets = [ItemAsset]()
            fetchResult.enumerateObjects { (asset: PHAsset, _, _) in
                let assetIdentifier: String = asset.localIdentifier
                itemAssets.append(ItemAsset(localIdentifier: assetIdentifier, asset: asset))
                }
            
            DispatchQueue.main.async {
                self.currentAssets.append(contentsOf: itemAssets)
                self.isProcessing.toggle()
            }
        }
    }
    
    func getState() -> LibraryState {
        return self.libraryState
    }
    
    func validateFileName(fileName: String, parentFolder: String, isNonCorrect: Binding<Bool>) {
        if fileName.isEmpty || fileName.count < 2 {
            isNonCorrect.wrappedValue.toggle()
            return
        }
        if parentFolder.isEmpty {
            for itemCollection: ItemCollection in self.userCollections {
                if fileName == itemCollection.id {
                    isNonCorrect.wrappedValue.toggle()
                    return
                }
            }
        } else {
            for itemCollection: ItemCollection in self.currentAlbumsCollection {
                if fileName == itemCollection.id {
                    isNonCorrect.wrappedValue.toggle()
                    return
                }
            }
        }
    }
    
    private func createNewFolder(name: String, completion: @escaping ()-> Void) {
        libraryState = .creating
        concurrentQueue.async {
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges  {
                let changeRequest: PHCollectionListChangeRequest = PHCollectionListChangeRequest.creationRequestForCollectionList(withTitle: name)
                placeholder = changeRequest.placeholderForCreatedCollectionList
            } completionHandler: { (success: Bool, error: Error? ) in
                guard let placeholder = placeholder, success, error == nil else
                {
                    print("Folder hasn't been created with error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                let fetchResult: PHFetchResult<PHCollectionList>  = PHCollectionList.fetchCollectionLists(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let folder: PHCollectionList = fetchResult.firstObject, let folderName: String = folder.localizedTitle, folderName == name else {
                    print("Error of creating the folder.")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                DispatchQueue.main.async {
                    let tempCollection: ItemCollection = ItemCollection(name: name, collection: folder)
                    self.userCollections.append(tempCollection)
                    print("Folder with name \(name) has been created.")
                    completion()
                    self.libraryState = .idle
                }
            }
        }
    }
    
     private func createAlbum(name: String, rootCollectionName: String) {
        libraryState = .creating
        concurrentQueue.async {
            guard let rootFolder: PHCollectionList = self.userCollections.first(where: { (item: ItemCollection) in
                if let collName: String = item.collection.localizedTitle {
                    return collName == rootCollectionName
                } else {
                    return false
                }
            })?.collection as? PHCollectionList else {
                print("Error of finding folder with name \(rootCollectionName).")
                DispatchQueue.main.async {
                    self.libraryState = .idle
                }
                return
            }
            var placeholderInFolder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges {
                guard let listRequest:PHCollectionListChangeRequest = PHCollectionListChangeRequest(for: rootFolder) else {
                    print("Error of creation album request in folder with id \(rootCollectionName).")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                let placeholder: PHObjectPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                listRequest.addChildCollections([placeholder] as NSFastEnumeration)
                placeholderInFolder = placeholder
            } completionHandler: { (success:Bool, error: Error?) in
                guard  let placeholder = placeholderInFolder, success, error == nil else {
                    print("Album with name \(name) hasn't been created in folder \(rootCollectionName) with error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let album: PHAssetCollection = fetchResult.firstObject, let albumName: String = album.localizedTitle, albumName == name else {
                    print("Error of creating the album.")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                DispatchQueue.main.async {
                    let tempCollection: ItemCollection = ItemCollection(name: name, collection: album)
                    self.currentAlbumsCollection.append(tempCollection)
                    print("Album with name \(name) has been created.")
                    self.libraryState = .idle
                }
            }
        }
    }
    
    private func createRootAlbum(name: String) {
       libraryState = .creating
       concurrentQueue.async {
           var placeholderInFolder: PHObjectPlaceholder?
           PHPhotoLibrary.shared().performChanges {
               let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
               let placeholder: PHObjectPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
               placeholderInFolder = placeholder
           } completionHandler: { (success:Bool, error: Error?) in
               guard  let placeholder = placeholderInFolder, success, error == nil else {
                   print("Album with name \(name) hasn't been created root folder with error: \(String(describing: error))")
                   DispatchQueue.main.async {
                       self.libraryState = .idle
                   }
                   return
               }
               let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
               guard let album: PHAssetCollection = fetchResult.firstObject, let albumName: String = album.localizedTitle, albumName == name else {
                   print("Error of creating the album.")
                   DispatchQueue.main.async {
                       self.libraryState = .idle
                   }
                   return
               }
               DispatchQueue.main.async {
                   let tempCollection: ItemCollection = ItemCollection(name: name, collection: album)
                   self.currentAlbumsCollection.append(tempCollection)
                   print("Album with name \(name) has been created.")
                   self.libraryState = .idle
               }
           }
       }
   }
    
    
    func createAssetForAlbum(image: UIImage, albumName: String) {
        libraryState = .creating
        concurrentQueue.async {
            guard let assetCollection: PHAssetCollection = self.currentAlbumsCollection.first(where: { (item: ItemCollection) in
                return item.id == albumName
            })?.collection as? PHAssetCollection else {
                print("Error of finding album with name \(albumName).")
                DispatchQueue.main.async {
                    self.libraryState = .idle
                }
                return
            }
            var placeholderInFolder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges {
                let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                guard let albumChangeRequest: PHAssetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection), let photoPlaceHolder: PHObjectPlaceholder = createAssetRequest.placeholderForCreatedAsset else {
                    print("Error of creation asset request in album with id \(albumName).")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                albumChangeRequest.addAssets([photoPlaceHolder] as NSFastEnumeration)
                placeholderInFolder = photoPlaceHolder
            } completionHandler: { (success: Bool, error: Error?) in
                guard  let placeholder = placeholderInFolder, success, error == nil else {
                    print("Asset hasn't been created in album \(albumName) with error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                let fetchResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let asset: PHAsset = fetchResult.firstObject else {
                    print("Error of creating the asset.")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                let tempAsset: ItemAsset = ItemAsset(localIdentifier: asset.localIdentifier, asset: asset)
                self.updateLocation(for: tempAsset.asset) { (success:Bool,error: Error?) in
                    print("Finished updating asset. " + (success ? "Success." : error!.localizedDescription))
                    DispatchQueue.main.async {
                        self.currentAssets.append(tempAsset)
                        print("Asset has been created.")
                        self.libraryState = .idle
                    }
                }
            }
        }
    }
    
    func createAssetForUnsortedAlbum(image: UIImage) {
        self.createAssetForAlbum(image: image, albumName: defaultAlbumName)
    }
    
    
    func createAssetForDefaultAlbum(image: UIImage) {
        libraryState = .creating
        concurrentQueue.async {
            var placeholderInFolder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                guard let photoPlaceHolder: PHObjectPlaceholder = creationRequest.placeholderForCreatedAsset else {
                    print("Error of creation asset request.")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                placeholderInFolder = photoPlaceHolder
            } completionHandler: { (success: Bool, error: Error?) in
                guard  let placeholder = placeholderInFolder, success, error == nil else {
                    print("Asset hasn't been created with error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                let fetchResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let asset: PHAsset = fetchResult.firstObject else {
                    print("Error of creating the asset.")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                let tempAsset: ItemAsset = ItemAsset(localIdentifier: asset.localIdentifier, asset: asset)
                self.updateLocation(for: tempAsset.asset) { (success:Bool,error: Error?) in
                    print("Finished updating asset. " + (success ? "Success." : error!.localizedDescription))
                    DispatchQueue.main.async {
                        print("Asset has been created.")
                        self.libraryState = .idle
                    }
                }
            }
        }
    }
    
  
    
    
    func findOrCreateDefaultRootFolder() {
        libraryState = .loading
        self.userCollections.removeAll()
        self.currentAlbumsCollection.removeAll()
        concurrentQueue.async {
            let options: PHFetchOptions = PHFetchOptions()
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: defaultCollectionName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            options.predicate = predicate
            
            let fetchCollectionResult: PHFetchResult<PHCollection> = PHCollectionList.fetchTopLevelUserCollections(with: options)
            if let collection: PHCollectionList = fetchCollectionResult.firstObject as? PHCollectionList {
                let options: PHFetchOptions = PHFetchOptions()
                let firstExpr = NSExpression(forKeyPath: "localizedTitle")
                let secondExpr = NSExpression(forConstantValue: defaultAlbumName)
                let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
                options.predicate = predicate
                let fetchResult: PHFetchResult<PHCollection> = PHCollectionList.fetchCollections(in: collection, options: options)
                if let album: PHAssetCollection = fetchResult.firstObject as? PHAssetCollection, let albumTitle: String = album.localizedTitle {
                    print("Folder and album with name \(albumTitle) have been founded")
                    DispatchQueue.main.async {
                        self.currentAlbumsCollection.append(ItemCollection(name: albumTitle, collection: album))
                        self.libraryState = .idle
                    }
                } else {
                    self.createAlbum(name: defaultAlbumName, rootCollectionName: defaultCollectionName)
                }
            } else {
                self.createNewFolder(name: defaultCollectionName, completion: {
                    self.createAlbum(name: defaultAlbumName, rootCollectionName: defaultCollectionName)
                })
            }
        }
    }
    
    func findOrCreateRootAssetCollection() {
        libraryState = .loading
        self.userCollections.removeAll()
        self.currentAlbumsCollection.removeAll()
        concurrentQueue.async {
            let options: PHFetchOptions = PHFetchOptions()
            let firstExpr = NSExpression(forKeyPath: "localizedTitle")
            let secondExpr = NSExpression(forConstantValue: defaultAlbumName)
            let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
            options.predicate = predicate
            let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
            if let assetCollect: PHAssetCollection =  fetchResult.firstObject, let albumTitle: String = assetCollect.localizedTitle {
                print("Album with name \(albumTitle) have been founded")
                DispatchQueue.main.async {
                    self.currentAlbumsCollection.append(ItemCollection(name: albumTitle, collection: assetCollect))
                    self.libraryState = .idle
                }
            } else {
                self.createRootAlbum(name: defaultAlbumName)
            }
        }
    }
    
    func deleteAsset(asset: ItemAsset) {
        libraryState = .deleting
        concurrentQueue.async {
            guard let currentAsset: ItemAsset = self.currentAssets.first(where: { (item:ItemAsset) in
                return asset.id == item.id
            }) else {
                print("Error of finding the asset.")
                DispatchQueue.main.async {
                    self.libraryState = .idle
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                guard let enumeration: NSFastEnumeration =  [currentAsset.asset] as? NSFastEnumeration else {
                    print("Error of delete asset with id \(currentAsset.id).")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                PHAssetChangeRequest.deleteAssets(enumeration)
            } completionHandler: { (success: Bool, error: Error?) in
                guard  success, error == nil else {
                    print("Asset \(currentAsset.id) hasn't been deleted  with error: \(String(describing: error))")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                guard let index: Int = self.currentAssets.firstIndex(where: { (item:ItemAsset) in
                    return item.id == currentAsset.id
                }) else {
                    print("Asset \(currentAsset.id) hasn't been deleted.")
                    DispatchQueue.main.async {
                        self.libraryState = .idle
                    }
                    return
                }
                DispatchQueue.main.async {
                    let removedAsset: ItemAsset = self.currentAssets.remove(at: index)
                    print("Asset \(removedAsset.id) has been deleted successfully.")
                    self.libraryState = .idle
                }
            }
        }
    }
    
    func createNewAlbumCollection(name: String) async throws -> String  {
        await setLibraryState(.creating)
        let options: PHFetchOptions = PHFetchOptions()
        let firstExpr = NSExpression(forKeyPath: "localizedTitle")
        let secondExpr = NSExpression(forConstantValue: name)
        let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
        options.predicate = predicate
        let findResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        if let assetCollect: PHAssetCollection =  findResult.firstObject, let albumTitle: String = assetCollect.localizedTitle, name == albumTitle {
            print("Album with name \(albumTitle) have been founded")
            DispatchQueue.main.async {
                self.libraryState = .idle
            }
            return assetCollect.localIdentifier
        }
        var placeholderInFolder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            let placeholder: PHObjectPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                placeholderInFolder = placeholder
        })
        guard let placeholder = placeholderInFolder else {
            print("Album with name \(name) hasn't been created root folder with error")
            await setLibraryState(.idle)
            throw PhotoError.creationError
        }
        let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
        guard let album: PHAssetCollection = fetchResult.firstObject, let albumName: String = album.localizedTitle, albumName == name else {
            print("Error of creating the album.")
            await setLibraryState(.idle)
            throw PhotoError.creationError
        }
        print("Album with name \(name) has been created.")
        await setLibraryState(.idle)
        return  placeholder.localIdentifier
    }
    
    func renameAssetCollection(oldName: String, newName: String) async throws -> String {
        await setLibraryState(.creating)
        let options: PHFetchOptions = PHFetchOptions()
        let firstExpr = NSExpression(forKeyPath: "localizedTitle")
        let secondExpr = NSExpression(forConstantValue: oldName)
        let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
        options.predicate = predicate
        let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        guard let assetCollection: PHAssetCollection = fetchResult.firstObject, let albumTitle: String = assetCollection.localizedTitle, albumTitle == oldName  else {
            print("Error of finding the album with name \(oldName).")
            await setLibraryState(.idle)
            throw PhotoError.missingData
        }
        try await PHPhotoLibrary.shared().performChanges({
            guard let changeAlbumRequest = PHAssetCollectionChangeRequest(for: assetCollection) else {
                print("Error of renaming the album with name \(oldName).")
                DispatchQueue.main.async {
                    self.libraryState = .idle
                }
                return
            }
            changeAlbumRequest.title = newName
        })
        await setLibraryState(.idle)
        return assetCollection.localIdentifier
    }
    
    func createAssetForAlbum(image: UIImage, albumName: String) async throws -> String {
        await setLibraryState(.creating)
        let options: PHFetchOptions = PHFetchOptions()
        let firstExpr = NSExpression(forKeyPath: "localizedTitle")
        let secondExpr = NSExpression(forConstantValue: albumName)
        let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
        options.predicate = predicate
        let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        guard let assetCollection: PHAssetCollection = fetchResult.firstObject, let albumTitle: String = assetCollection.localizedTitle, albumTitle == albumName  else {
            print("Error of finding the album with name \(albumName).")
            await setLibraryState(.idle)
            throw PhotoError.missingData
        }
            var placeholderInFolder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            guard let albumChangeRequest: PHAssetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection), let photoPlaceHolder: PHObjectPlaceholder = createAssetRequest.placeholderForCreatedAsset else {
                print("Error of creation asset request in album \(albumName).")
                DispatchQueue.main.async {
                    self.libraryState = .idle
                }
                return
            }
            albumChangeRequest.addAssets([photoPlaceHolder] as NSFastEnumeration)
            placeholderInFolder = photoPlaceHolder
        })
        guard  let placeholder = placeholderInFolder else {
            print("Asset hasn't been created in album \(albumName)")
            await setLibraryState(.idle)
            throw PhotoError.missingData
        }
        let fetchAssetResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
        guard let asset: PHAsset = fetchAssetResult.firstObject else {
            print("Error of creating the asset.")
            await setLibraryState(.idle)
            throw PhotoError.missingData
        }
        print("Asset has been created.")
        try await PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.location = self.locationManager.location
        })
        print("Finished updating asset.")
        await setLibraryState(.idle)
        return asset.localIdentifier
    }
    
    func getAssetsFromAlbum(albumName: String) -> [ItemAsset] {
        DispatchQueue.main.async {
            self.libraryState = .loading
        }
        let options: PHFetchOptions = PHFetchOptions()
        let firstExpr = NSExpression(forKeyPath: "localizedTitle")
        let secondExpr = NSExpression(forConstantValue: albumName)
        let predicate: NSComparisonPredicate = NSComparisonPredicate(leftExpression: firstExpr, rightExpression: secondExpr, modifier: NSComparisonPredicate.Modifier.direct, type: NSComparisonPredicate.Operator.equalTo, options: NSComparisonPredicate.Options.caseInsensitive)
        options.predicate = predicate
        let fetchResult: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        guard let assetCollection: PHAssetCollection = fetchResult.firstObject, let albumTitle: String = assetCollection.localizedTitle, albumTitle == albumName  else {
            print("Error of finding the album with name \(albumName).")
            DispatchQueue.main.async {
                self.libraryState = .idle
            }
            return [ItemAsset]()
        }
        let assetsOptions: PHFetchOptions = PHFetchOptions()
        assetsOptions.sortDescriptors = [NSSortDescriptor(key: "mediaType", ascending: true), NSSortDescriptor(key: "creationDate", ascending: true)]
                   let fetchAssetResult: PHFetchResult<PHAsset> = PHAsset.fetchAssets(in: assetCollection, options: assetsOptions)
                   var tempCollection: [ItemAsset] = [ItemAsset]()
        fetchAssetResult.enumerateObjects { (asset: PHAsset, _, _) in
                       tempCollection.append(ItemAsset(localIdentifier: asset.localIdentifier, asset: asset))
                   }
        DispatchQueue.main.async {
            self.libraryState = .idle
        }
        return tempCollection
    }
    
    
    func loadAssetsFromAlbum(albumName: String) {
        currentAssets.removeAll()
        currentAssets = getAssetsFromAlbum(albumName: albumName)
    }
    
    @MainActor func setLibraryState(_ state: LibraryState) {
        self.libraryState = state
    }
    
    func createImage(asset: PHAsset) -> Image? {
        var img: Image?
        self.imageManager.requestImage(for: asset, targetSize: CGSize(width: 420.0, height: 420.0), contentMode: .aspectFill, options: nil, resultHandler: { (image: UIImage?, dict: [AnyHashable : Any]?)in
            if let assetImage: UIImage = image, dict?[PHImageErrorKey] == nil {
                img = Image(uiImage: assetImage)
            }
        })
        return img
    }
    
    func getAssetImage(asset: PHAsset, completionHandler: @escaping (Image)-> Void) {
        asset.requestContentEditingInput(with: nil) { (input:PHContentEditingInput?, dictionary: [AnyHashable : Any] )in
            guard let resultInput: PHContentEditingInput = input, let image: UIImage = resultInput.displaySizeImage else {
                return
            }
            
            completionHandler(Image(uiImage: image))
        }
    }
    
    func getAssetUrl(asset: PHAsset, completionHandler: @escaping (String, URL, Date, Double, Double)-> Void) {
        asset.requestContentEditingInput(with: nil) { (input:PHContentEditingInput?, dictionary: [AnyHashable : Any] )in
            guard let resultInput: PHContentEditingInput = input, let url: URL = resultInput.fullSizeImageURL else {
                return
            }
            var defaultCreationDate: Date = Date()
            if let createDate: Date = resultInput.creationDate {
                defaultCreationDate = createDate
            }
            var latitude: Double = 0.0
            var longitude: Double = 0.0
            if let coordinate: CLLocationCoordinate2D = resultInput.location?.coordinate {
                latitude = coordinate.latitude
                longitude = coordinate.longitude
            }
            let assetIdentifier: String = asset.localIdentifier
            completionHandler(assetIdentifier, url, defaultCreationDate,
                              latitude, longitude)
        }
    }
    
    func getAssetData(asset: PHAsset, completionHandler: @escaping (ItemAssetDataView?, NSError?)-> Void)  {
        self.imageManager.requestImageDataAndOrientation(for: asset, options: self.imageOptions) { (data: Data?, _, _, infoKey: [AnyHashable : Any]?) in
            if let imgData: Data = data, let info:[AnyHashable : Any] = infoKey, info[PHImageErrorKey] == nil {
                var defaultCreationDate: Date = Date()
                if let createDate: Date = asset.creationDate {
                    defaultCreationDate = createDate
                }
                var latitude: Double = 0.0
                var longitude: Double = 0.0
                if let coordinate: CLLocationCoordinate2D = asset.location?.coordinate {
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                }
                let assetIdentifier: String = asset.localIdentifier
                let item = ItemAssetDataView(localIdentifier: assetIdentifier, imgData: imgData, creationDate: defaultCreationDate, latitude: latitude, longitude: longitude)
                completionHandler(item, nil)
            } else {
                if let info:[AnyHashable : Any] = infoKey, let error: NSError = info[PHImageErrorKey] as? NSError {
                    completionHandler(nil, error)
                } else {
                    completionHandler(nil, NSError(domain: "Photo library module", code: 2001, userInfo: [NSLocalizedDescriptionKey: "can't create image from asset \(asset.localIdentifier)."]))
                }
                
            }
        }
    }
    
    
    private func updateLocation(for asset: PHAsset, completionHandler: @escaping  (Bool, Error?)-> Void) {
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.location = self.locationManager.location
        } completionHandler: { success, error in
            completionHandler(success,error)
        }
    }
}

extension PhotoLibraryController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
    }
}

func libraryState(state: LibraryState) -> String {
    var str: String = String()
    switch state {
    case .loading:
        str = "Loading..."
        break
    case .saving:
        str = "Saving..."
        break
    case .deleting:
        str = "Deleting..."
        break
    case .uploading:
        str = "Uploading..."
        break
    case .creating:
        str = "Creating..."
        break
    default:
        break
    }
    return str
}

func createRandomImage() -> UIImage {
    let size = (arc4random_uniform(2) == 0) ?
        CGSize(width: 400, height: 300) :
        CGSize(width: 300, height: 400)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        UIColor(hue: CGFloat(arc4random_uniform(100)) / 100,
                saturation: 1, brightness: 1, alpha: 1).setFill()
        context.fill(context.format.bounds)
    }
    return image
}

func createRandomImageToData() -> Data {
    let size = (arc4random_uniform(2) == 0) ?
        CGSize(width: 400, height: 300) :
        CGSize(width: 300, height: 400)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        UIColor(hue: CGFloat(arc4random_uniform(100)) / 100,
                saturation: 1, brightness: 1, alpha: 1).setFill()
        context.fill(context.format.bounds)
    }
    guard let data: Data = image.jpegData(compressionQuality: 1.0) else {
        return Data()
    }
    return data
}


func convertImageToGrayScale(image: UIImage) -> UIImage? {
    let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
    let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
    let context = CGContext(data: nil, width: Int(rect.size.width), height: Int(rect.size.height), bitsPerComponent: 16, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
    
    guard let cgImage = image.cgImage else {
        return nil
    }
    context?.draw(cgImage, in: rect)
    
    if let newImageCG = context?.makeImage() {
        return UIImage(cgImage: newImageCG)
    } else {
        return nil
    }
}
