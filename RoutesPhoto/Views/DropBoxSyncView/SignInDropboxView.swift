//
//  SignInDropboxView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.10.2022.
//

import SwiftUI

struct SignInDropboxView: View {
    @ObservedObject var authViewModel: AuthenticationDropBoxModel
    var body: some View {
        VStack {
            Image("dropbox").resizable().frame(width: 50,height: 50)
            Button {
                authViewModel.signIn()
            } label: {
                Text("Login to DropBox")
            }
            Spacer()
        }
    }
}

struct SignInDropboxView_Previews: PreviewProvider {
    static var previews: some View {
        SignInDropboxView(authViewModel: AuthenticationDropBoxModel())
    }
}
