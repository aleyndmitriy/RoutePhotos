//
//  GoogleFolderSynchProgressView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 11.09.2022.
//

import SwiftUI
import GoogleSignIn

struct GoogleFolderSynchProgressView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    @ObservedObject var authViewModel: AuthenticationGoogleViewModel
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    @State var newFileName: String?
    @State var singleSelection: String?
    @State var isSyncFinished: Bool = false
    @State var syncError: Error?
    
    private var user: GIDGoogleUser? {
        return authViewModel.currentUser()
    }
     var googleOneDriveService = GoogleOneDriveService()
    
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
        VStack(alignment: .center) {
            if let userProfile = user?.profile {
                Text(userProfile.name).padding(.trailing, 16).padding(.leading, 16)
                Text(userProfile.email).padding(.trailing, 16).padding(.leading, 16).foregroundColor(.gray)
            }
        }
    }
    
    private func prepareService() {
        loadCurrentUser()
        Task {
            do {
                remoteFolderEditObject.childFolders = try await googleOneDriveService.searchRootFodersWithOutChild()
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
        loadCurrentUser()
        Task {
            do {
                 try await googleOneDriveService.searchFirstChildFolders(folder)
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
        loadCurrentUser()
        guard let select: String = singleSelection, let folder: RemoteFolderItem = remoteFolderEditObject.getFolder(folderId: select) else {
            loadCurrentUser()
            Task {
                do {
                    let res = try await  googleOneDriveService.createFolder(folderName: newName, parentFolderId: "root")
                    remoteFolderEditObject.childFolders = try await googleOneDriveService.searchRootFodersWithOutChild()
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
                let res = try await  googleOneDriveService.createFolder(folderName: newName, parentFolderId: select)
                try await googleOneDriveService.searchFirstChildFolders(folder)
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
    
    private func loadCurrentUser() {
        if let currentUser = user {
            if authViewModel.hasGoogleDriveFilesScope {
                googleOneDriveService.fetchServiceAutorization(user: currentUser)
            } else {
                authViewModel.addGoogleDriveFilesScope {
                    googleOneDriveService.fetchServiceAutorization(user: currentUser)
                }
            }
        }
    }
}

struct GoogleFolderSynchProgressView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleFolderSynchProgressView(authViewModel: AuthenticationGoogleViewModel(),remoteFolderEditObject: RemoteFolderEditObject())
    }
}
