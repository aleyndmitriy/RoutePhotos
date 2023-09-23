//
//  GoogleFolderSynchView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 11.09.2022.
//

import SwiftUI
import GoogleSignIn

struct GoogleFolderSynchView: View {
    
    @StateObject private var authViewModel = AuthenticationGoogleViewModel()
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Spacer()
            switch authViewModel.state {
            case .signedIn:
                GoogleFolderSynchProgressView(authViewModel: authViewModel,remoteFolderEditObject: remoteFolderEditObject)
            case .signedOut:
                SignInGoogleView(authViewModel: authViewModel)
            }
            Spacer()
        }.onOpenURL { (url: URL) in
            authViewModel.shareUrl(url)
        }.onAppear {
            authViewModel.restorePreviousSign()
        }
    }
    
}

struct GoogleFolderSynchView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleFolderSynchView(remoteFolderEditObject: RemoteFolderEditObject())
    }
}
