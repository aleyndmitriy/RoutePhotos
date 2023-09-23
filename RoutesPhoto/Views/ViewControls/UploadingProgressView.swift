//
//  UploadingProgressView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.08.2022.
//

import SwiftUI
import MSAL

struct UploadingProgressView: View {
    @Binding var isUploading: Bool
    @Binding var uploadingError: Error?
    @ObservedObject var authViewModel: AuthenticationOneDriveModel
    var albumItem: FolderItem
    var photoItem: PhotosProperties
    private var account: MSALAccount? {
        return authViewModel.currentAccount()
    }
     var oneDriveService = MicroSoftOneDriveService()
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            profileTitle()
            if isUploading {
                ProgressView {
                    Text("Uploading...")
                }
            }
            Spacer()
        }.onAppear(perform: prepareService)
    }
    
    private func profileTitle()-> some View {
        HStack(alignment: .center) {
            if let userProfile = account?.username {
                Text(userProfile)
                  .font(.headline)
            }
        }
    }
    
    private func toolbarButtons() -> some View {
        HStack(alignment: .center) {
            if let _ = account {
                Spacer()
                Button {
                    authViewModel.signOut()
                    isUploading.toggle()
                } label: {
                    Text("Sign Out")
                }.padding()
            }
        }
    }
    
    private func prepareService() {
        Task {
            do {
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                let sent: SentPhotosProperties = SentPhotosProperties(id: photoItem.id.uuidString, photoName: photoItem.name, albumIdentifier: albumItem.id, creationDate: photoItem.date, latitude: photoItem.latitude, longitude: photoItem.longitude, image: photoItem.image, remoteAlbumIdentifier: albumItem.remoteId, remoteType: 2, sessionId: UUID())
                let sync: SyncPhotosProperties = try await self.oneDriveService.uploadFile(sendigPhoto: sent)
                isUploading.toggle()
            } catch {
                uploadingError = error
                isUploading.toggle()
            }
        }
    }
    
}

struct UploadingProgressView_Previews: PreviewProvider {
    static var previews: some View {
        UploadingProgressView(isUploading: .constant(true), uploadingError: .constant(nil), authViewModel: AuthenticationOneDriveModel(), albumItem: FolderItem(id: UUID().uuidString, localName: "Localfolder", remoteId: UUID().uuidString, remoteName: "", source: FolderSource.googledrive, order: 0,nonSyncNumber: 4, totalNumber: 10), photoItem: PhotosProperties(image: createRandomImageToData(), longitude: -116.166_868, latitude: 34.011_286))
    }
}
