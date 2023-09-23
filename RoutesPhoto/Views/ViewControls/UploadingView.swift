//
//  UploadingView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.08.2022.
//

import SwiftUI
import GoogleSignIn

struct UploadingView: View {
    @Binding var isUploading: Bool
    @State private var isError: Bool = false
    @State private var uploadingError: Error?
    let albumItem: FolderItem
    var photoItem: PhotosProperties
    @StateObject private var authViewModel = AuthenticationOneDriveModel()
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            switch authViewModel.state {
            case .signedIn:
                UploadingProgressView(isUploading: $isUploading, uploadingError: $uploadingError, authViewModel: authViewModel, albumItem: albumItem, photoItem: photoItem)
            case .signedOut:
                SignInOneDriveView(authViewModel: authViewModel)
            }
            Spacer()
        }.background(.white)
    }
}

struct UploadingView_Previews: PreviewProvider {
    static var previews: some View {
        UploadingView(isUploading: .constant(true), albumItem: FolderItem(id: UUID().uuidString, localName: "Localfolder", remoteId: UUID().uuidString, remoteName: "", source: FolderSource.googledrive, order: 0,nonSyncNumber: 4, totalNumber: 10), photoItem: PhotosProperties(image: createRandomImageToData(), longitude: -116.166_868, latitude: 34.011_286))
    }
}
