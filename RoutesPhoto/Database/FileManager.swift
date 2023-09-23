//
//  FileManager.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 04.07.2022.
//

import Foundation

protocol FilesInteractorOutput: AnyObject {
    func savedFile(isSaved: Bool, path: String?)
}

final class FilesInteractor {
    
    weak var output: FilesInteractorOutput?
    var fileError: FileError?
    
    private func saveData(data: Data, url: URL) -> Bool {
        self.fileError = nil
        do {
            try data.write(to: url)
        }
        catch {
            self.getError(error)
            return false
        }
        return true
    }
    
    func saveFile(data: Data, directory: String, fileName: String) -> URL? {
        self.fileError = nil
        let paths = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)
        let subPath: String = [directory, fileName].joined(separator:"/")
        if let documentUrl: URL = paths.first {
            let writablePath: URL = documentUrl.appendingPathComponent(subPath)
            if !FileManager.default.fileExists(atPath: writablePath.relativePath) {
                let folderPath = writablePath.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: folderPath.relativePath) {
                    do {
                        try FileManager.default.createDirectory(atPath: folderPath.relativePath,
                                                                withIntermediateDirectories: true,
                                                                attributes: nil)
                    }
                    catch {
                        output?.savedFile(isSaved: false, path: nil)
                        self.getError(error)
                        return nil
                    }
                }
                let isSaved: Bool = saveData(data: data, url: writablePath)
                output?.savedFile(isSaved: isSaved, path: subPath)
                return writablePath
            }
            else {
                do {
                    try FileManager.default.removeItem(at: writablePath)
                }
                catch {
                    output?.savedFile(isSaved: false, path: nil)
                    self.getError(error)
                    return nil
                }
                let isSaved: Bool = saveData(data: data, url: writablePath)
                output?.savedFile(isSaved: isSaved, path: subPath)
                return writablePath
            }
        }
        else {
            self.getError(FileError.missingData)
            output?.savedFile(isSaved: false, path: nil)
            return nil
        }
    }
    
    func deleteFile(directory: String, fileName: String?)-> Bool {
        self.fileError = nil
        let paths = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask)
        guard let documentUrl: URL = paths.first else {
            return false
        }
        var subPath: String = directory
        if let nameOfFile = fileName {
            subPath = [directory, nameOfFile].joined(separator:"/")
        }
        let writablePath: URL = documentUrl.appendingPathComponent(subPath)
        if FileManager.default.fileExists(atPath: writablePath.relativePath) {
            do {
                try FileManager.default.removeItem(at: writablePath)
            }
            catch {
                self.getError(error)
                return false
            }
        }
        return true
    }
    
    func saveFileToTempDir(data: Data, fileName: String) {
        self.fileError = nil
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)
        
        output?.savedFile(isSaved: saveData(data: data, url: url), path: url.path)
    }
    
   func getError(_ err: Error) {
        if let err: FileError = err as? FileError {
            self.fileError = err
        } else {
            self.fileError = .unexpectedError(error: err)
        }
    }
}
