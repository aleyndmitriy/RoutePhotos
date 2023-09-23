//
//  AuthenticationOneDriveModel.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 10.11.2022.
//

import UIKit
import MSAL

enum OneDriveAuthState {
  case signedIn(MSALAccount)
  case signedOut
}

class AuthenticationOneDriveModel: NSObject, ObservableObject {
    
    let kClientId = "28cb5028-ed80-476d-8128-62451aeefd9a"
    let kCurrentAccountIdentifier = "MSALOneDriveAccountIdentifier"
    let kAuthority = "https://login.microsoftonline.com/common"
    let scope = "files.readwrite.all"
    @Published var state: OneDriveAuthState
    
    var currentAccountIdentifier: String? {
        get {
            return UserDefaults.standard.string(forKey: self.kCurrentAccountIdentifier)
        }
        set (accountIdentifier) {
            UserDefaults.standard.set(accountIdentifier, forKey: self.kCurrentAccountIdentifier)
        }
    }
    
    override init() {
        self.state = .signedOut
        super.init()
        if let account = currentAccount() {
            self.state = .signedIn(account)
        }
    }
    
    func createClientApplication() -> MSALPublicClientApplication? {
        guard let urlAuth: URL = URL(string: kAuthority) else {
            return nil
        }
        guard let authority: MSALAADAuthority = try? MSALAADAuthority(url: urlAuth) else {
            return nil
        }
        // This MSALPublicClientApplication object is the representation of your app listing, in MSAL. For your own app
        // go to the Microsoft App Portal to register your own applications with their own client IDs.
        let config = MSALPublicClientApplicationConfig(clientId: kClientId, redirectUri: nil, authority: authority)
       
        guard let application: MSALPublicClientApplication = try? MSALPublicClientApplication(configuration: config) else {
            return nil
        }
        return application
    }
    
    func currentAccount() -> MSALAccount? {
        guard let accountIdentifier = currentAccountIdentifier else {
            return nil
        }
        guard let application: MSALPublicClientApplication = self.createClientApplication() else {
            return nil
        }
        guard let account: MSALAccount = try? application.account(forIdentifier: accountIdentifier) else {
            clearCurrentAccount()
            return nil
        }
        return account
    }
    
    func clearCurrentAccount() {
        UserDefaults.standard.removeObject(forKey: kCurrentAccountIdentifier)
    }
    
    func signIn() {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController  else {
          print("There is no root view controller!")
          return
        }
        guard let application: MSALPublicClientApplication = self.createClientApplication() else {
            return
        }
        let webParameters = MSALWebviewParameters(authPresentationViewController: rootViewController)
        let parameters = MSALInteractiveTokenParameters(scopes: [scope], webviewParameters: webParameters)
        application.acquireToken(with: parameters) { (result:MSALResult?, error: Error? ) in
            guard let acquireTokenResult = result, error == nil else {
                return
            }
            let signedInAccount = acquireTokenResult.account
            self.currentAccountIdentifier = signedInAccount.homeAccountId?.identifier
            DispatchQueue.main.async {
                self.state = .signedIn(signedInAccount)
            }
        }
    }
    
    func signOut() {
        guard let accountToDelete = self.currentAccount() else {
            return
        }
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController  else {
          print("There is no root view controller!")
          return
        }
      
        guard let application: MSALPublicClientApplication = self.createClientApplication() else {
            return
        }
        let webParameters = MSALWebviewParameters(authPresentationViewController: rootViewController)
        let signOutParameters = MSALSignoutParameters(webviewParameters: webParameters)
        signOutParameters.signoutFromBrowser = false
        application.signout(with: accountToDelete, signoutParameters: signOutParameters) { (success: Bool, error:Error?) in
            if error == nil {
                DispatchQueue.main.async {
                    self.state = .signedOut
                    self.clearCurrentAccount()
                }
            }
        }
    }
    
    func acquireTokenSilentForCurrentAccount(forScopes scopes:[String]) async throws -> String {
        guard let application = self.createClientApplication() else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Application is empty."])
            throw err
        }
        guard let account = self.currentAccount() else {
            let err: Error = NSError(domain: "OneDrive sync module", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Account is empty."])
            throw err
        }
        
        let parameters = MSALSilentTokenParameters(scopes: scopes, account: account)
        let acquireTokenResult = try await application.acquireTokenSilent(with: parameters)
        return acquireTokenResult.accessToken
    }
    
    func shareUrl(_ url: URL) {
        MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    }
}
