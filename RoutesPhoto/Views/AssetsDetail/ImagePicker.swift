//
//  ImagePicker.swift
//  RoutesPhoto
//
//  Created by Vasili Orlov on 24/10/22.
//

import Foundation
import SwiftUI
import PhotosUI


struct ImagePicker: UIViewControllerRepresentable {
    
    @State var completion: (_ items: [ItemAssetBaseView]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        let photoLibrary = PHPhotoLibrary.shared()
        var configuration = PHPickerConfiguration(photoLibrary: photoLibrary)
        configuration.filter = .images
        configuration.selectionLimit = 32
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        
        typealias AssetData = (photoId: String, url: URL, creationDate: Date, latitude: Double, longitude: Double)
        typealias AssetDataRequestCallBack = (Result<AssetData, Error>) -> Void
        
        var parent: ImagePicker
        private var dispatchGroup = DispatchGroup()
        private let imageManager = PHImageManager.default()
        private var imageOptions = PHImageRequestOptions()
        init(_ parent: ImagePicker) {
            self.parent = parent
            self.imageOptions.version = .current
            self.imageOptions.isSynchronous = true
            self.imageOptions.isNetworkAccessAllowed = true
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.view.isUserInteractionEnabled = false
            let options: PHFetchOptions = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)
            var currentAssetsImage: [ItemAssetBaseView] = []
            self.dispatchGroup = DispatchGroup()
            
            fetchResult.enumerateObjects { (asset: PHAsset, _, _) in
                self.dispatchGroup.enter()
                self.getAssetData(asset: asset) { (itemData: ItemAssetDataView?, error: NSError?) in
                    guard let item: ItemAssetDataView = itemData, error == nil else {
                        self.dispatchGroup.leave()
                        return
                    }
                    currentAssetsImage.append(item)
                    self.dispatchGroup.leave()
                }
                /*self.getAssetUrl(asset: asset) { result in
                    
                    switch result {
                    case .success(let data):
                        let item = ItemAssetView(localIdentifier: data.photoId,
                                                 url: data.url,
                                                 creationDate: data.creationDate,
                                                 latitude: data.latitude,
                                                 longitude: data.longitude)
                        currentAssetsImage.append(item)
                        self.dispatchGroup.leave()
                        
                    case .failure(_):
                        self.dispatchGroup.leave()
                    }
                    
                }*/
            }
            
            self.dispatchGroup.notify(queue: .main) {
                self.parent.completion(currentAssetsImage)
            }
        }
        
        func getAssetUrl(asset: PHAsset, completionHandler: @escaping AssetDataRequestCallBack) {
            asset.requestContentEditingInput(with: nil) { (input:PHContentEditingInput?, dictionary: [AnyHashable : Any] )in
                guard let resultInput: PHContentEditingInput = input, let url: URL = resultInput.fullSizeImageURL else {
                    let error = NSError(domain: "No result input", code: 1000, userInfo: nil)
                    completionHandler(.failure(error))
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
                let assetData = (assetIdentifier, url, defaultCreationDate, latitude, longitude)
                completionHandler(.success(assetData))
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
    }
}
