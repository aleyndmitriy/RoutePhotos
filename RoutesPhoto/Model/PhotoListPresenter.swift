//
//  PhotoListPresenter.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.09.2022.
//
import CoreLocation
import UIKit
import SwiftUI

class ImageProperties: Identifiable, Hashable {
    let id: UUID
    let name: String
    let image: Image
    let date: Date
    let longitude: Double
    let latitude: Double
    let address: String
    let status: PhotoStatus
    
    init(id: UUID, name: String, image: Image, date: Date, longitude: Double, latitude: Double, address: String, status: PhotoStatus) {
        self.id = id
        self.name = name
        self.image = image
        self.date = date
        self.longitude = longitude
        self.latitude = latitude
        self.address = address
        self.status = status
    }
    
    
    convenience init(image: Image, longitude: Double, latitude: Double) {
        self.init(id: UUID(), name: "ExampleName", image: image, date: Date(), longitude: longitude, latitude: latitude, address: "unknown", status: .local)
    }
    
    convenience init(image: Image) {
        self.init(id: UUID(), name: "ExampleName",image: image, date: Date(), longitude: 0.0, latitude: 0.0,address: String(), status: .local)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: ImageProperties, rhs: ImageProperties) -> Bool {
        return lhs.id == rhs.id
    }
}


class PhotoListPresenter: NSObject {
    let locationManager: CLLocationManager = CLLocationManager()
    let geoCoder: CLGeocoder = CLGeocoder()
    
    override init() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func loadPhotoFromAlbum(albumId: String, albumName: String) async throws -> [ImageProperties] {
        let res: [PhotosProperties] = try await CoreDataSyncAssetDatabase.shared.loadPhoto(localId: albumId, localName: albumName)
        let images: [ImageProperties] = res.compactMap { (property: PhotosProperties) in
            return self.mapScaledImageFromData(property)
        }
        return images
    }
    
    func loadIdsPhotoFromAlbum(albumId: String, albumName: String) async throws -> [UUID] {
        let res: [PhotosProperties] = try await CoreDataSyncAssetDatabase.shared.loadPhoto(localId: albumId, localName: albumName)
        let imagesId: [UUID] = res.compactMap { (property: PhotosProperties) in
            return property.id
        }
        return imagesId
    }
    
    func loadCurrentPhotoFromAlbum(albumId: String, albumName: String, photoId: UUID) async throws -> ImageProperties {
        let res: [PhotosProperties] = try await CoreDataSyncAssetDatabase.shared.loadPhoto(localId: albumId, localName: albumName)
        for corePhoto: PhotosProperties in res {
            if corePhoto.id == photoId, let image: ImageProperties = self.mapImageFromData(corePhoto) {
                return image
            }
        }
        throw NSError(domain: "PhotoList", code: 2007, userInfo: [NSLocalizedDescriptionKey: "Photo does not exist."])
    }
    
    func loadCurrentPhotoMessags(albumId: String, albumName: String, photoId: UUID) async throws -> [MessageProperties] {
        let res: [MessageProperties] = try await CoreDataSyncAssetDatabase.shared.loadMessages(localId: albumId, localName: albumName, photoId: photoId)
        return res
    }
    
    func createMessage(albumId: String, albumName: String, photoId: UUID, messageName: String, text: String) async throws {
        let message: MessageProperties = MessageProperties(id: UUID(), photoId: photoId.uuidString, name: messageName, text: text, date: Date(), status: .local)
        try await CoreDataSyncAssetDatabase.shared.insertMessage(localId: albumId, localName: albumName, messages: [message])
    }
    func updateMessage(albumId: String, albumName: String, message: MessageProperties) async throws {
        try await CoreDataSyncAssetDatabase.shared.updateMessage(localId: albumId, albumName: albumName,newMessage: message)
    }
    func deletePhoto(albumId: String, albumName: String, photoId: UUID) async throws {
        try await CoreDataSyncAssetDatabase.shared.deletePhoto(localId: albumId, albumName: albumName, photoPropertyId: photoId)
    }
    
    func deletePhotos(albumId: String, albumName: String, photosIds: [UUID]) async throws {
        try await CoreDataSyncAssetDatabase.shared.deletePhotos(localId: albumId, albumName: albumName, photoPropertiesIDs: photosIds)
    }
    
    func updatePhotoName(albumId: String, albumName: String, photoId: UUID, newName: String) async throws {
        try await CoreDataSyncAssetDatabase.shared.updatePhotoName(localId: albumId, albumName: albumName, photosId: photoId, newName: newName)
    }
    
    func updateAddressPhoto(albumId: String, albumName: String, photo: ImageProperties) async throws -> String {
        guard  photo.longitude != 0 || photo.latitude != 0 else {
            throw NSError(domain: "PhotoList", code: 2007, userInfo: [NSLocalizedDescriptionKey: "Empty locations degrees."])
        }
        let location: CLLocation = CLLocation(latitude: photo.latitude, longitude: photo.longitude)
        let placeMarks: [CLPlacemark] =  try await geoCoder.reverseGeocodeLocation(location)
        if let place: CLPlacemark = placeMarks.first, let locality: String = place.locality {
            var address = locality
            if let subLocality: String = place.subLocality {
                address = locality + " " + subLocality
            }
            try await CoreDataSyncAssetDatabase.shared.updatePhotoAddress(localId: albumId, albumName: albumName, photosId: photo.id, address: address)
            return address
        } else {
            throw NSError(domain: "PhotoList", code: 2007, userInfo: [NSLocalizedDescriptionKey: "Cant'n get locations address."])
        }
    }
    
    private func mapImageFromData(_ property: PhotosProperties) -> ImageProperties? {
        guard let kitImg: UIImage = UIImage(data:property.image) else {
            return nil
        }
        let uiImage: Image = Image(uiImage: kitImg)
        return ImageProperties(id: property.id, name: property.name, image: uiImage, date: property.date, longitude: property.longitude, latitude: property.latitude, address: property.address, status: property.status)
    }
    
    
    private func mapScaledImageFromData(_ property: PhotosProperties) -> ImageProperties? {
        guard let kitImg: UIImage = UIImage(data:property.image), let imgThumbnail: UIImage = resizeImageWithAspect(image: kitImg, scaledToMaxWidth: 120, maxHeight: 120) else {
            return nil
        }
        
        let uiImage: Image = Image(uiImage: imgThumbnail)
        return ImageProperties(id: property.id, name: property.name, image: uiImage, date: property.date, longitude: property.longitude, latitude: property.latitude, address: property.address, status: property.status)
    }
    
    private func resizeImageWithAspect(image: UIImage,scaledToMaxWidth width:CGFloat,maxHeight height :CGFloat)->UIImage? {
        let oldWidth = image.size.width;
        let oldHeight = image.size.height;
        
        let scaledBy = (oldWidth > oldHeight) ? width / oldWidth : height / oldHeight;
        
        let newHeight = oldHeight * scaledBy;
        let newWidth = oldWidth * scaledBy;
        let newSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContextWithOptions(newSize,false,UIScreen.main.scale);
            
            image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height));
            let newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            return newImage
    }
}

