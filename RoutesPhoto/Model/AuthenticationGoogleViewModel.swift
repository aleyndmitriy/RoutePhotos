//
//  AuthenticationGoogleViewModel.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.08.2022.
//

import SwiftUI
import GoogleSignIn

enum GoogleAuthState {
  case signedIn(GIDGoogleUser)
  case signedOut
}

final class AuthenticationGoogleViewModel: ObservableObject {
  @Published var state: GoogleAuthState
  private var authenticator: SignInGoogleAuthenticator {
    return SignInGoogleAuthenticator(authViewModel: self)
  }
    
  var authorizedScopes: [String] {
    switch state {
    case .signedIn(let user):
      return user.grantedScopes ?? []
    case .signedOut:
      return []
    }
  }

  init() {
    if let user = GIDSignIn.sharedInstance.currentUser {
      self.state = .signedIn(user)
    } else {
      self.state = .signedOut
    }
  }
  
  func signIn() {
    authenticator.signIn()
  }
  
  func signOut() {
    authenticator.signOut()
  }

  func disconnect() {
    authenticator.disconnect()
  }

  var hasGoogleDriveFilesScope: Bool {
      for str: String in authorizedScopes {
          print("\(str) \n")
      }
    return authorizedScopes.contains(GOOGLE_DRIVE_FILES_SCOPE)
  }

  func addGoogleDriveFilesScope(completion: @escaping () -> Void) {
    authenticator.addGoogleDriveFilesScope(completion: completion)
  }
    
    func restorePreviousSign() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
          if let user = user {
            self.state = .signedIn(user)
          } else if let error = error {
            self.state = .signedOut
            print("There was an error restoring the previous sign-in: \(error)")
          } else {
            self.state = .signedOut
          }
        }
    }
    
    func restorePreviousGoogleSign() async throws -> GIDGoogleUser {
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let user = user {
                    self.state = .signedIn(user)
                    continuation.resume(returning: user)
                } else if let error = error {
                    self.state = .signedOut
                    print("There was an error restoring the previous sign-in: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    self.state = .signedOut
                    let err: Error = NSError(domain: "Authentication Google Service", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Signed out state "])
                    continuation.resume(throwing: err)
                }
            }
        }
    }
    
    func shareUrl(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }
    
    func currentUser() -> GIDGoogleUser? {
        return GIDSignIn.sharedInstance.currentUser
    }
}

