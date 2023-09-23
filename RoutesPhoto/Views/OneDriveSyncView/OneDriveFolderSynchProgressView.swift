//
//  OneDriveFolderSynchProgressView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 10.11.2022.
//

import SwiftUI
import MSAL

struct OneDriveFolderSynchProgressView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    @ObservedObject var authViewModel: AuthenticationOneDriveModel
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    @State var newFileName: String?
    @State var singleSelection: String?
    @State var isSyncFinished: Bool = false
    @State var syncError: Error?
    
    private var oneDriveAccount: MSALAccount? {
        return authViewModel.currentAccount()
    }
    var oneDriveService: MicroSoftOneDriveService = MicroSoftOneDriveService()
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Group {
                if isSyncFinished {
                    if let err: Error = syncError {
                        Spacer()
                        Text(err.localizedDescription).font(.title3)
                        Button {
                            navigationStateManager.selectionPath.removeLast()
                        } label: {
                            Text("Cancel").font(.title2).foregroundColor(.white)
                        }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                            .overlay {
                                RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                            }
                        Spacer()
                    } else {
                        ListGoogleDriveFoldersView(remoteFolderEditObject: remoteFolderEditObject, isSyncFinished: $isSyncFinished,singleSelection: $singleSelection, newFileName: $newFileName)
                    }
                } else {
                    profileTitle()
                    ProgressView(synchronizingProgress)
                    Text(synchronizingMessage).padding(.trailing, 16).padding(.leading, 16).foregroundColor(.gray)
                    Spacer()
                }
                
            }
        }.onAppear(perform: prepareService).onChange(of: singleSelection) { newValue in
            if let select = newValue {
               
                print(select)
                
            }
        }.onChange(of: isSyncFinished) { newValue in
            if newValue == false, let select: String = singleSelection {
                loadChildren(select)
            }
        }.onChange(of: newFileName) { newValue in
            if let newFileName: String = newValue {
                createNewFile(newFileName)
            }
        }
    }
    
    private func profileTitle()-> some View {
        HStack(alignment: .center) {
            if let _ = oneDriveAccount {
                Button {
                    authViewModel.signOut()
                } label: {
                    Text("Logout")
                }

            }
        }
    }
    
    private func prepareService() {
        Task {
            do {
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                remoteFolderEditObject.childFolders = try await self.oneDriveService.searchRootFodersWithOutChild()
                remoteFolderEditObject.processTreeToOneDimentionList()
                isSyncFinished.toggle()
            } catch {
                syncError = error
                isSyncFinished.toggle()
            }
        }
    }
    
    private func loadChildren(_ selection: String) {
        guard let folder: RemoteFolderItem = remoteFolderEditObject.getFolder(folderId: selection) else {
            isSyncFinished.toggle()
            return
        }
        if let child = folder.children, child.isEmpty == false {
            folder.expanded = true
            remoteFolderEditObject.processTreeToOneDimentionList()
            isSyncFinished.toggle()
            return
        }
        Task {
            do {
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                 try await self.oneDriveService.searchFirstChildFolders(folder)
                folder.expanded = true
                remoteFolderEditObject.processTreeToOneDimentionList()
                isSyncFinished.toggle()
            } catch {
                syncError = error
                isSyncFinished.toggle()
            }
        }
    }
    
    private func createNewFile(_ newName: String) {
        guard let select: String = singleSelection, let folder: RemoteFolderItem = remoteFolderEditObject.getFolder(folderId: select) else {
            Task {
                do {
                    let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                    self.oneDriveService.setCurrentToken(token: token)
                    let res = try await  self.oneDriveService.createFolder(driveId: String(), parentId: String(), folderName: newName)
                    remoteFolderEditObject.childFolders = try await self.oneDriveService.searchRootFodersWithOutChild()
                    remoteFolderEditObject.processTreeToOneDimentionList()
                    newFileName = nil
                   isSyncFinished.toggle()
                } catch {
                    newFileName = nil
                    syncError = error
                    isSyncFinished.toggle()
                }
            }
            return
        }
        Task {
            do {
                let token: String = try await authViewModel.acquireTokenSilentForCurrentAccount(forScopes: [authViewModel.scope])
                self.oneDriveService.setCurrentToken(token: token)
                let res = try await  self.oneDriveService.createFolder(driveId:remoteFolderEditObject.remoteDriveId, parentId: select, folderName: newName)
                try await self.oneDriveService.searchFirstChildFolders(folder)
               folder.expanded = true
               remoteFolderEditObject.processTreeToOneDimentionList()
                newFileName = nil
               isSyncFinished.toggle()
                
            } catch {
                newFileName = nil
                syncError = error
                isSyncFinished.toggle()
            }
        }
    }
}

struct OneDriveFolderSynchProgressView_Previews: PreviewProvider {
    static var previews: some View {
        OneDriveFolderSynchProgressView(authViewModel: AuthenticationOneDriveModel(), remoteFolderEditObject: RemoteFolderEditObject())
    }
}
