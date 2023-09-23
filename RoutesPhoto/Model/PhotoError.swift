//
//  PhotoError.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 03.07.2022.
//

import Foundation
enum PhotoError: Error {
    case wrongDataFormat(error: Error)
    case missingData
    case creationError
    case updateError
    case deleteError
    case batchInsertError
    case batchDeleteError
    case persistentHistoryChangeError
    case unexpectedError(error: Error)
}

extension PhotoError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .wrongDataFormat(let error):
            return NSLocalizedString("Could not digest the fetched data. \(error.localizedDescription)", comment: "")
        case .missingData:
            return NSLocalizedString("Found and will discard a photo missing a valid location or time.", comment: "")
        case .creationError:
            return NSLocalizedString("Failed to create a new Photo object.", comment: "")
        case .updateError:
            return NSLocalizedString("Failed to update a Photo object.", comment: "")
        case .deleteError:
            return NSLocalizedString("Failed to delete a Photo object.", comment: "")
        case .batchInsertError:
            return NSLocalizedString("Failed to execute a batch insert request.", comment: "")
        case .batchDeleteError:
            return NSLocalizedString("Failed to execute a batch delete request.", comment: "")
        case .persistentHistoryChangeError:
            return NSLocalizedString("Failed to execute a persistent history change request.", comment: "")
        case .unexpectedError(let error):
            return NSLocalizedString("Received unexpected error. \(error.localizedDescription)", comment: "")
        }
    }
}

extension PhotoError: Identifiable {
    var id: String? {
        errorDescription
    }
}
