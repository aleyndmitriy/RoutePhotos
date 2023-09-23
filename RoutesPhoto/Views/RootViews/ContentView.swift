//
//  ContentView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 15.08.2022.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var internetMonitor: NetworkMonitor
    var synchronizer = Synchronizer.shared
    var permissions = PermissionsModel()
    var coreDataController = SyncAssetDatabaseAccessObject()
    var photoListPresenter: PhotoListPresenter = PhotoListPresenter()
    @StateObject var navigationStateManager = NavigationStateManager()
    @StateObject var remoteFolderEditObject = RemoteFolderEditObject()
    var body: some View {
        NavigationStack(path: $navigationStateManager.selectionPath) {
            RootLibraryView().onAppear{
                synchronizer.resume()
            }.navigationDestination(for: NavigationState.self) {
                state in
                    switch state {
                    case .photoDetail(let albumId, let albumName, let photoId):
                        AssetsTabView(photoListPresenter: photoListPresenter,albumId: albumId, albumName: albumName, selectedTab: photoId)
                    case .editFolder(let folderId, let folderName):
                        CreateFolderModalWithPickerView( remoteFolderEditObject: remoteFolderEditObject, coreDataController: coreDataController, albumId: folderId, folderName: folderName)
                    case .editPicture(let folderId, let folderName, let pictureId):
                        ChangePictureNameView(photoListPresenter: photoListPresenter, folderId: folderId,folderName: folderName, pictureId: pictureId)
                    case .addMessage(let folderId, let folderName, let pictureId):
                        AddMessageView(photoListPresenter: photoListPresenter, folderId: folderId,folderName: folderName, pictureId: pictureId)
                    case .addComment(let folderId, let folderName, let pictureId):
                        AddCommentView(photoListPresenter: photoListPresenter, folderId: folderId,folderName: folderName, pictureId: pictureId)
                    case .camera(let folderId, let folderName):
                        CameraView(photoListPresenter: photoListPresenter, albumId: folderId, folderName: folderName)
                    case .photoLibrary(let folderId, let folderName):
                        AddPhotoLibraryAssetsView(albumId:folderId,albumName: folderName)
                    case .photoList(let folderId):
                        AssetsList(photoListPresenter: photoListPresenter, albumId: folderId)
                    case .remoteGoogleSync:
                        GoogleFolderSynchView(remoteFolderEditObject: remoteFolderEditObject)
                    case .remoteDropBoxSync:
                        DropBoxFolderSynchView(remoteFolderEditObject: remoteFolderEditObject)
                    case .remoteOneDriveSync:
                        OneDriveFolderSynchView(remoteFolderEditObject: remoteFolderEditObject)
                    case .addFolder:
                        CreateFolderModalWithPickerView(remoteFolderEditObject: remoteFolderEditObject, coreDataController: coreDataController)
                    case .settings:
                        SettingsView()
                    }
            }
        }.environment(\.colorScheme, .light).environmentObject(navigationStateManager).environmentObject(internetMonitor)
            
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
