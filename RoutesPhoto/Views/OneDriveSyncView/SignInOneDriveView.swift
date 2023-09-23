//
//  SignInOneDriveView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 10.11.2022.
//

import SwiftUI

struct SignInOneDriveView: View {
    @ObservedObject var authViewModel: AuthenticationOneDriveModel
    var body: some View {
        VStack {
            Image("onedrive").resizable().frame(width: 50,height: 50)
            Button {
                authViewModel.signIn()
            } label: {
                Text("Login to OneDrive")
            }
            Spacer()
        }
    }
}

struct SignInOneDriveView_Previews: PreviewProvider {
    static var previews: some View {
        SignInOneDriveView(authViewModel: AuthenticationOneDriveModel())
    }
}
