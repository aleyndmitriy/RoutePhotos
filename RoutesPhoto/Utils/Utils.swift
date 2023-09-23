//
//  Utils.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.12.2022.
//

import Foundation

let synchronizingProgress: String = "Synchronizing..."
let synchronizingMessage: String = "Depending on your connection this process might take up to 8 - 10 minutes... Please wait."
func isNonZeroCoordinate(latitude: Double, longitude: Double)-> Bool {
    if fabs(latitude) < 0.000001 && fabs(longitude) < 0.000001 {
        return false
    }
    return true
}

func dateFotmatter() -> DateFormatter {
    let formatter = DateFormatter()
    //let usLocale = Locale(identifier: "en_US")
    //let gbLocale = Locale(identifier: "en_GB")
    let template = "dd.MM.yy  HH:mm"
    if let format = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .current) {
        let temporaryFormat: String = format.replacingOccurrences(of: "/", with: ".").replacingOccurrences(of: ",", with: " ")
        formatter.dateFormat = temporaryFormat
    } else {
        formatter.locale = .current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
    }
    //formatter.dateFormat = "dd.MM.yy  HH:mm"
    return formatter
}

func fileNameSuffix(name: String, fullName: String) -> Bool {
   
    guard fullName.hasPrefix(name) else {
        return false
    }
    var suffix: String = String(fullName)
    suffix.removeFirst(name.count)
    if suffix.isEmpty {
        return true
    }
    if let dotIndex = suffix.lastIndex(of: ".") {
        suffix.removeSubrange(dotIndex..<suffix.endIndex)
        if suffix.isEmpty {
            return true
        }
        if suffix.count < 2 {
            return false
        }
        if suffix[suffix.startIndex] != "(" || suffix[suffix.index(before: suffix.endIndex)] != ")" {
            return false
        }
        return true
    } else {
        if suffix.isEmpty {
            return true
        }
        if suffix.count < 2 {
            return false
        }
        if suffix[suffix.startIndex] != "(" || suffix[suffix.index(before: suffix.endIndex)] != ")" {
            return false
        }
        return true
    }
}

func removeFileExtension(fileName: String) -> String {
    var correctedName: String = String(fileName)
    if let dotIndex = correctedName.lastIndex(of: ".") {
        correctedName.removeSubrange(dotIndex..<correctedName.endIndex)
        return correctedName
    }
    return correctedName
}
