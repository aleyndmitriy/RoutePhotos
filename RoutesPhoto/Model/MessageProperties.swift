//
//  MessageProperties.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 25.01.2023.
//

import Foundation

class MessageProperties: Identifiable, Hashable, Codable {
    let id: UUID
    let photoId: String
    let name: String
    let text: String
    let date: Date
    let status: PhotoStatus
    
    init(id: UUID, photoId: String, name: String, text: String, date: Date, status: PhotoStatus) {
        self.id = id
        self.photoId = photoId
        self.name = name
        self.text = text
        self.date = date
        self.status = status
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MessageProperties, rhs: MessageProperties) -> Bool {
        return lhs.id == rhs.id
    }
}
