//
//  PhotosProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 03.07.2022.
//

import Foundation
import UIKit

enum PhotoStatus: Int16, CaseIterable, Codable {
    case local = 0
    case pending
    case synchronized
}

class PhotosProperties: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let image: Data
    let date: Date
    let longitude: Double
    let latitude: Double
    let address: String
    let status: PhotoStatus
    
    init(id: UUID, name: String, image: Data, date: Date, longitude: Double, latitude: Double, address: String, status: PhotoStatus) {
        self.id = id
        self.name = name
        self.image = image
        self.date = date
        self.longitude = longitude
        self.latitude = latitude
        self.address = address
        self.status = status
    }
    
    convenience init(name: String, image: Data, date: Date, longitude: Double, latitude: Double, address: String, status: PhotoStatus) {
        self.init(id: UUID(), name: name, image: image, date: date, longitude: longitude, latitude: latitude, address: address, status: status)
    }
    
    convenience init(name: String, image: Data, date: Date, longitude: Double, latitude: Double, address: String) {
        self.init(name: name, image: image, date: date, longitude: longitude, latitude: latitude, address: address, status: .local)
    }
    
    convenience init(id: UUID, image: Data, date: Date, longitude: Double, latitude: Double, address: String, status: PhotoStatus) {
        self.init(id: UUID(), name: PhotosProperties.nameFromLocationAndDate(address: address, date: date), image: image, date: date, longitude: longitude, latitude: latitude, address: address, status: status)
    }
    
    convenience init(id: UUID, image: Data, date: Date, longitude: Double, latitude: Double, status: PhotoStatus) {
        self.init(id: UUID(), name: PhotosProperties.nameFromLocationAndDate(address: String(), date: date), image: image, date: date, longitude: longitude, latitude: latitude, address: String(), status: status)
    }
    
    convenience init(image: Data, date: Date, longitude: Double, latitude: Double, address: String) {
        self.init(id: UUID(), image: image, date: date, longitude: longitude, latitude: latitude, address: address,status: .local)
    }
    
    convenience init(image: Data, longitude: Double, latitude: Double, address: String) {
        self.init(image: image, date: Date(), longitude: longitude, latitude: latitude,address: address)
    }
    
    convenience init(image: Data, longitude: Double, latitude: Double) {
        self.init(image: image, date: Date(), longitude: longitude, latitude: latitude, address: "unknown")
    }
    convenience init(image: Data) {
        self.init(image: image, date: Date(), longitude: 0.0, latitude: 0.0,address: String())
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: PhotosProperties, rhs: PhotosProperties) -> Bool {
        return lhs.id == rhs.id
    }
    
    static private func randomPhotoName(length: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzÂĆĒĪÑØŚÜŸ"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    static private let PhotoNameLenght: Int = 10
    
    static private func nameFromLocationAndDate(address: String, date: Date) -> String {
        let name: String = dateFormatter.string(from: date) + address
        return name
    }
    
    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        let template = "yyyy-MM-dd 'T' HH:mm:ss"
        if let format = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .current) {
           let temporaryFormat: String = format.replacingOccurrences(of: ".", with: "-").replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ", ", with: "'T'").appending("_")
            formatter.dateFormat = temporaryFormat
            print(format)
            print(temporaryFormat)
        } else {
            formatter.locale = .current
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
        }
        return formatter
    }()
}
