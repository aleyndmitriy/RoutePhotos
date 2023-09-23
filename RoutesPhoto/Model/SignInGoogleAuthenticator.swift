//
//  SignInGoogleAuthenticator.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.08.2022.
//

import Foundation
import GoogleSignIn

let GOOGLE_DRIVE_FILES_SCOPE: String = "https://www.googleapis.com/auth/drive.file"

final class SignInGoogleAuthenticator: ObservableObject {

    private let clientID = "404946805984-u3qoeistivac48544dta6q4qf78i6pt4.apps.googleusercontent.com"
  

    private lazy var configuration: GIDConfiguration = {
        return GIDConfiguration(clientID: clientID)
    }()

    private var authViewModel: AuthenticationGoogleViewModel

    init(authViewModel: AuthenticationGoogleViewModel) {
        self.authViewModel = authViewModel
    }

  func signIn() {
    guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
      print("There is no root view controller!")
      return
    }

    GIDSignIn.sharedInstance.signIn(with: configuration,
                                    presenting: rootViewController) { user, error in
      guard let user = user else {
        print("Error! \(String(describing: error))")
        return
      }
        DispatchQueue.main.async {
            self.authViewModel.state = .signedIn(user)
        }
    }
  }

  /// Signs out the current user.
  func signOut() {
    GIDSignIn.sharedInstance.signOut()
      DispatchQueue.main.async {
          self.authViewModel.state = .signedOut
      }
  }

  /// Disconnects the previously granted scope and signs the user out.
  func disconnect() {
    GIDSignIn.sharedInstance.disconnect { error in
      if let error = error {
        print("Encountered error disconnecting scope: \(error).")
      }
      self.signOut()
    }
  }

  
  func addGoogleDriveFilesScope(completion: @escaping () -> Void) {
      guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
      fatalError("No root view controller!")
    }

    GIDSignIn.sharedInstance.addScopes([GOOGLE_DRIVE_FILES_SCOPE],
                                       presenting: rootViewController) { user, error in
      if let error = error {
        print("Found error while adding file scope: \(error).")
          self.disconnect()
        return
      }

      guard let currentUser = user else { return }
        DispatchQueue.main.async {
            self.authViewModel.state = .signedIn(currentUser)
        }
      completion()
    }
  }

}

