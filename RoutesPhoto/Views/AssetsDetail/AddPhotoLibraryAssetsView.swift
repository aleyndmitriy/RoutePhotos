//
//  AddPhotoLibraryAssetsView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 17.10.2022.
//

import SwiftUI

struct AddPhotoLibraryAssetsView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    let albumId: String
    let albumName: String
    @State var additionError: Error?
    @State private var isProgressing: Bool = false
    @State var isError: Bool = false
    @StateObject private var photoLibrary = PhotoLibraryController()
    private let photoCreator = PhotoCreator()
    var body: some View {
        VStack {
            ImagePicker { items in
                createPhotosBy(items)
            }
            if isProgressing {
                ProgressView {
                    Text("Inserting...")
                }
            }
            if let err: Error = additionError {
                Text(err.localizedDescription)
            }
        }.navigationBarHidden(true)
    }
    
    private func createPhotosBy(_ asset: [ItemAssetBaseView]) {
        isProgressing.toggle()
        Task {
            if asset.isEmpty {
                isProgressing.toggle()
                navigationStateManager.selectionPath.removeLast()
                return
            }
            do {
                
              try await photoCreator.savePhoto(assets: asset, albumId: albumId, albumName: albumName)
                isProgressing.toggle()
                navigationStateManager.selectionPath.removeLast()
            } catch {
                isProgressing.toggle()
                additionError = error
                isError.toggle()
                navigationStateManager.selectionPath.removeLast()
            }
        }
    }
}

struct AddPhotoLibraryAssetsView_Previews: PreviewProvider {
    static var previews: some View {
        AddPhotoLibraryAssetsView(albumId:UUID().uuidString, albumName: "Localfolder")
    }
}
