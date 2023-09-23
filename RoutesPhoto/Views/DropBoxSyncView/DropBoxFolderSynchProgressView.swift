//
//  DropBoxFolderSynchProgressView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.10.2022.
//

import SwiftUI
import SwiftyDropbox

struct DropBoxFolderSynchProgressView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    @ObservedObject var authViewModel: AuthenticationDropBoxModel
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    @State var newFileName: String?
    @State var singleSelection: String?
    @State var isSyncFinished: Bool = false
    @State var syncError: Error?
    
    private var dropBoxClient: DropboxClient? {
        return authViewModel.currentClient()
    }
    var googleDropBoxService: GoogleDropBoxService = GoogleDropBoxService()
    
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
            if let _ = dropBoxClient {
                Button {
                    authViewModel.signOut()
                } label: {
                    Text("Logout")
                }

            }
        }
    }
    
    private func prepareService() {
        guard let client = dropBoxClient  else {
            return
        }
        googleDropBoxService.client = client
        Task {
            do {
                remoteFolderEditObject.childFolders = try await googleDropBoxService.searchRootFodersWithOutChild()
                remoteFolderEditObject.processTreeToOneDimentionList()
                    isSyncFinished.toggle()
                } catch {
                    syncError = error
                    isSyncFinished.toggle()
                }
            }
           
        
    }
    
    private func loadChildren(_ selection: String) {
        guard let client = dropBoxClient, let folder: RemoteFolderItem = remoteFolderEditObject.getFolder(folderId: selection) else {
            isSyncFinished.toggle()
            return
        }
        googleDropBoxService.client = client
        if let child = folder.children, child.isEmpty == false {
            folder.expanded = true
            remoteFolderEditObject.processTreeToOneDimentionList()
            isSyncFinished.toggle()
            return
        }
        Task {
            do {
                 try await googleDropBoxService.searchFirstChildFolders(folder)
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
        guard let client = dropBoxClient  else {
            return
        }
        googleDropBoxService.client = client
        guard let select: String = singleSelection, let folder: RemoteFolderItem = remoteFolderEditObject.getFolder(folderId: select) else {
            Task {
                do {
                    let res = try await  googleDropBoxService.createFolder(folderName: newName, parentFolderId: "")
                    remoteFolderEditObject.childFolders = try await googleDropBoxService.searchRootFodersWithOutChild()
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
                let res = try await  googleDropBoxService.createFolder(folderName: newName, parentFolderId: remoteFolderEditObject.remoteFolderPath)
                try await googleDropBoxService.searchFirstChildFolders(folder)
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

struct DropBoxFolderSynchProgressView_Previews: PreviewProvider {
    static var previews: some View {
        DropBoxFolderSynchProgressView( authViewModel: AuthenticationDropBoxModel(), remoteFolderEditObject: RemoteFolderEditObject())
    }
}
