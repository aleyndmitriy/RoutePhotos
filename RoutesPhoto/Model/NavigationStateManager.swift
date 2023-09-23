//
//  NavigationStateManager.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 08.01.2023.
//

import Foundation
enum NavigationState: Hashable, Codable {
    case photoDetail(String,String,UUID)
    case photoLibrary(String,String)
    case editFolder(String,String)
    case editPicture(String,String,UUID)
    case addMessage(String,String,UUID)
    case addComment(String,String,UUID)
    case photoList(String)
    case camera(String,String)
    case remoteGoogleSync
    case remoteDropBoxSync
    case remoteOneDriveSync
    case addFolder
    case settings
}

class NavigationStateManager: ObservableObject {
    @Published var selectionPath = [NavigationState]()
    
    func popToRoot() {
        selectionPath.removeAll()
    }
    
    func goToSettings() {
        selectionPath = [NavigationState.settings]
    }
}
