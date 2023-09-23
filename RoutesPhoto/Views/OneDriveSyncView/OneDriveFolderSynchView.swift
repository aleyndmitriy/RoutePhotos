//
//  OneDriveFolderSynchView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 10.11.2022.
//

import SwiftUI

struct OneDriveFolderSynchView: View {
    @StateObject private var authViewModel = AuthenticationOneDriveModel()
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Spacer()
            switch authViewModel.state {
            case .signedIn:
                OneDriveFolderSynchProgressView(authViewModel: authViewModel,remoteFolderEditObject: remoteFolderEditObject)
            case .signedOut:
                SignInOneDriveView(authViewModel: authViewModel)
            }
            Spacer()
        }
    }
}

struct OneDriveFolderSynchView_Previews: PreviewProvider {
    static var previews: some View {
        OneDriveFolderSynchView(remoteFolderEditObject: RemoteFolderEditObject())
    }
}
