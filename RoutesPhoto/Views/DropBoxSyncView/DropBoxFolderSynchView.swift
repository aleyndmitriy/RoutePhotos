//
//  DropBoxFolderSynchView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 20.10.2022.
//

import SwiftUI
import SwiftyDropbox

struct DropBoxFolderSynchView: View {
    @StateObject private var authViewModel = AuthenticationDropBoxModel()
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Spacer()
            switch authViewModel.state {
            case .signedIn:
                DropBoxFolderSynchProgressView(authViewModel: authViewModel, remoteFolderEditObject: remoteFolderEditObject)
            case .signedOut:
                SignInDropboxView(authViewModel: authViewModel)
            }
            Spacer()
        }.onOpenURL { (url: URL) in
            authViewModel.shareUrl(url)
        }
    }
    
}

struct DropBoxFolderSynchView_Previews: PreviewProvider {
    static var previews: some View {
        DropBoxFolderSynchView(remoteFolderEditObject: RemoteFolderEditObject())
    }
}
