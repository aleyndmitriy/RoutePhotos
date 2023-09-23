//
//  AuthenticationDropBoxModel.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.10.2022.
//

import UIKit
import SwiftyDropbox
import SwiftUI
enum DropBoxAuthState {
  case signedIn(DropboxClient)
  case signedOut
}

final class AuthenticationDropBoxModel: NSObject, ObservableObject {
    @Published var state: DropBoxAuthState
    
    override init() {
        if let client = DropboxClientsManager.authorizedClient {
            self.state = .signedIn(client)
        } else {
            self.state = .signedOut
        }
        super.init()
    }
    
    func shareUrl(_ url: URL) {
        let oauthCompletion: DropboxOAuthCompletion = {
                        if let authResult = $0 {
                            switch authResult {
                            case .success:
                                print("Success! User is logged into DropboxClientsManager.")
                                if let client = DropboxClientsManager.authorizedClient {
                                    DispatchQueue.main.async {
                                        self.state = .signedIn(client)
                                    }
                                }
                            case .cancel:
                                print("Authorization flow was manually canceled by user!")
                            case .error(_, let description):
                                print("Error: \(String(describing: description))")
                            }
                        }
                    }
            DropboxClientsManager.handleRedirectURL(url, completion: oauthCompletion)
    }
    
    func currentClient() -> DropboxClient? {
        return DropboxClientsManager.authorizedClient
    }
    
    func signIn() {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController  else {
          print("There is no root view controller!")
          return
        }
       
        let scopeRequest = ScopeRequest(scopeType: .user, scopes: ["account_info.read", "sharing.write", "sharing.read", "files.content.write", "files.content.read"], includeGrantedScopes: false)
        DropboxClientsManager.authorizeFromControllerV2(
            UIApplication.shared,
            controller: rootViewController,
            loadingStatusDelegate: nil,
            openURL: { (url: URL) -> Void in UIApplication.shared.open(url, options: [:], completionHandler: nil ) },
            scopeRequest: scopeRequest)
        
    }
    
    func signOut() {
        DropboxClientsManager.unlinkClients()
        DispatchQueue.main.async {
            self.state = .signedOut
        }
    }
}
