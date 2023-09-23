//
//  PhotoCreator.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.09.2022.
//

import CoreLocation
import SwiftUI
import Firebase

class PhotoCreator: NSObject {
    let locationManager: CLLocationManager = CLLocationManager()
    let geoCoder: CLGeocoder = CLGeocoder()
    let context = CIContext()
    let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    override init() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func savePhoto(ciImage: CIImage, albumId: String, albumName: String) async throws {
       
        guard let imgData: Data = context.jpegRepresentation(of: ciImage, colorSpace: colorSpace) else {
            print("Can't save image into file")
            throw PhotoError.creationError
        }
        var property: PhotosProperties = PhotosProperties(image: imgData)
       
        if let location: CLLocation = self.locationManager.location {
            do {
                let placeMarks: [CLPlacemark] =  try await geoCoder.reverseGeocodeLocation(location)
                if let place: CLPlacemark = placeMarks.first, let locality: String = place.locality {
                var address = locality
                    if let subLocality: String = place.subLocality {
                        address = locality + " " + subLocality
                    }
                    
                    if let street: String = place.thoroughfare {
                        address = street
                        if let number: String = place.subThoroughfare {
                            address = address + " " + number
                        }
                    }
                    
                    property = PhotosProperties(image: imgData, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude, address: address)
                } else {
                    property = PhotosProperties(image: imgData, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude)
                }
                
            } catch {
                property = PhotosProperties(image: imgData, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude)
            }
        }
        do {
            try await CoreDataSyncAssetDatabase.shared.insertPhoto(localId: albumId, localName: albumName, photos: [property])
           
        } catch {
           throw error
        }
    }
    
    func savePhoto(assets: [ItemAssetBaseView], albumId: String, albumName: String) async throws {
        var photos: [PhotosProperties] = [PhotosProperties]()
        for asset: ItemAssetBaseView in assets {
            do {
                let photo: PhotosProperties = try await self.mapLibraryPhoto(asset: asset)
                photos.append(photo)
            } catch {
                print("error of asset with \(asset.id)")
            }
        }
        if photos.isEmpty == false {
            do {
                try await CoreDataSyncAssetDatabase.shared.insertPhoto(localId: albumId, localName: albumName, photos: photos)
            } catch {
               throw error
            }
        }
    }
    
    private func mapLibraryPhoto(asset: ItemAssetBaseView) async throws -> PhotosProperties {
        var imgData: Data?
        if let urlAsset: ItemAssetView = asset as? ItemAssetView {
            guard let fileData: NSData = NSData(contentsOf: urlAsset.url) else {
                throw PhotoError.creationError
            }
            imgData = Data(referencing: fileData)
        }
        if let imgAsset: ItemAssetDataView = asset as? ItemAssetDataView {
            imgData = imgAsset.imgData
        }
        guard let data: Data = imgData else {
            throw PhotoError.creationError
        }
        
        if isNonZeroCoordinate(latitude: asset.latitude, longitude: asset.longitude) {
            let location: CLLocation = CLLocation(latitude: asset.latitude, longitude: asset.longitude)
            do {
                let placeMarks: [CLPlacemark] =  try await geoCoder.reverseGeocodeLocation(location)
                if let place: CLPlacemark = placeMarks.first, let locality: String = place.locality {
                var address = locality
                    if let subLocality: String = place.subLocality {
                        address = locality + " " + subLocality
                    }
                    
                    if let street: String = place.thoroughfare {
                        address = street
                        if let number: String = place.subThoroughfare {
                            address = address + " " + number
                        }
                    }
                    
                    return PhotosProperties(image: data, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude, address: address)
                } else {
                    return PhotosProperties(image: data, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude)
                }
                
            } catch {
               return PhotosProperties(image: data, longitude: location.coordinate.longitude, latitude: location.coordinate.latitude)
            }
            
        } else {
            return PhotosProperties(id: UUID(), image: data, date: asset.creationDate, longitude: asset.longitude, latitude: asset.latitude, status: .local)
        }
    }
}
