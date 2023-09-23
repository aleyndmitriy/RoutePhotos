//
//  FileError.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 20.09.2022.
//

import Foundation

enum FileError: Error {
    case wrongDataFormat(error: Error)
    case missingData
    case saveError
    case updateError
    case deleteError
    case readError
    case unexpectedError(error: Error)
}

extension FileError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .wrongDataFormat(let error):
            return NSLocalizedString("Could not digest the fetched data. \(error.localizedDescription)", comment: "")
        case .missingData:
            return NSLocalizedString("Found and will discard a photo missing a valid location or time.", comment: "")
        case .saveError:
            return NSLocalizedString("Failed to save a new Image file.", comment: "")
        case .updateError:
            return NSLocalizedString("Failed to update a Image file.", comment: "")
        case .deleteError:
            return NSLocalizedString("Failed to delete a Image file.", comment: "")
        case .readError:
            return NSLocalizedString("Failed to read a Image file.", comment: "")
        case .unexpectedError(let error):
            return NSLocalizedString("Received unexpected error. \(error.localizedDescription)", comment: "")
        }
    }
}

extension FileError: Identifiable {
    var id: String? {
        errorDescription
    }
}
