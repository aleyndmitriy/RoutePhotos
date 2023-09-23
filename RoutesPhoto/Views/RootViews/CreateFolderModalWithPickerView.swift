//
//  CreateFolderModalWithPickerView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 05.10.2022.
//

import SwiftUI

struct CreateFolderModalWithPickerView: View {
    @EnvironmentObject var internetMonitor: NetworkMonitor
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
   var coreDataController: SyncAssetDatabaseAccessObject
    @FocusState var isNameFocused : Bool
    @State var isOnStack: Bool = false
    @State private var filename: String = String()
    @State private var selectedStorage: FolderSource = .googledrive
    @State private var isError: Bool = false
    @State private var creationError: Error?
    @State private var isCreationFinished: Bool = false
    @State private var isCancelEdition: Bool = false
    @State private var folderItem: FolderItem?
    var albumId: String?
    var folderName: String?
    var body: some View {
        VStack(alignment: .center, spacing: 10, content: {
                if let err: Error = creationError {
                    VStack {
                        Spacer()
                        Text(err.localizedDescription).font(.title3)
                        Button {
                            resetToInitialValues()
                        } label: {
                            Text("Ok").font(.title2).foregroundColor(.white)
                        }.frame(width: 100,height: 40).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                            .overlay {
                                RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                            }.padding(.trailing, 16)
                        Spacer()
                    }
                } else {
                    if isCancelEdition {
                        VStack{
                            Spacer()
                            Text("Do you want to save?").font(.title2)
                            Spacer()
                            HStack(alignment:.bottom){
                                Button {
                                    remoteFolderEditObject.clear()
                                    isCancelEdition.toggle()
                                    navigationStateManager.selectionPath.removeLast()
                                } label: {
                                    Text("No").font(.title2).foregroundColor(.white)
                                }.frame(width: 100,height: 40).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                    .overlay {
                                        RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                    }.padding(.trailing, 16)
                                
                                Button {
                                    if let editionFolder: FolderItem = self.folderItem {
                                        isCancelEdition.toggle()
                                                        self.checkEditionAlbum(editedFolder: editionFolder)
                                                    }
                                    else {
                                        isCancelEdition.toggle()
                                        self.checkCreationAlbum()
                                    }
                                } label: {
                                    Text("Yes").font(.title2).foregroundColor(.white)
                                }.frame(width: 100,height: 40).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                    .overlay {
                                        RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                    }.padding(.trailing, 16)
                            }
                        }
                    } else {
                        CoordinatorPlace().onChange(of: selectedStorage) { newValue in
                                if let editableItem: FolderItem = self.folderItem {
                                    if editableItem.folderSource == newValue {
                                        remoteFolderEditObject.remoteFolderId = editableItem.remoteId
                                        remoteFolderEditObject.remoteFolderPath = editableItem.remoteName
                                        remoteFolderEditObject.remoteDriveId = editableItem.remoteDriveId
                                    } else {
                                        remoteFolderEditObject.clear()
                                    }
                                } else {
                                    remoteFolderEditObject.clear()
                                }
                                isNameFocused = false
                            }
                            Spacer()
                    }
                }
        }).onAppear {
            
            if isOnStack == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isNameFocused = true
                       }
                loadingOnAppear()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).navigationBarBackButtonHidden().navigationTitle(titlePlace()).toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                            if isChangesHasBeenMade() {
                                    withAnimation {
                                        isCancelEdition.toggle()
                                    }
                            } else {
                                remoteFolderEditObject.clear()
                                navigationStateManager.selectionPath.removeLast()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }.frame(minWidth: 30.0, maxWidth: 40.0).buttonStyle(.plain).foregroundColor(.blue)
            }
        }
    }
    
    private func titlePlace() -> String {
        if self.folderItem != nil {
             return  "Edit Folder"
                } else {
                    return "Create Folder"
                }
    }
    
    private func CoordinatorPlace() -> some View {
        VStack(alignment:.center, spacing: 10) {
            ScrollView {
                HStack{
                    Text("Folder Name").font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)
                    Spacer()
                }.padding(.top, 50)
                VStack(alignment:.center, spacing: 5.0) {
                    TextField("Enter Folder  Name", text: $filename).font(.system(size: 20, weight: .light, design: .serif)).focused($isNameFocused,equals: true)
                        .onSubmit {
                            
                        }.frame(maxWidth:.infinity,minHeight: 25,maxHeight:25).padding(.leading, 16)
                    Rectangle().frame(maxWidth:.infinity,minHeight: 1,maxHeight: 1)
                                             .foregroundColor(.black).padding(.leading, 16)
                                             .padding(.trailing, 16)
                   
                }.padding(.bottom,50)
                
                HStack{
                    Text("File Storage").font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)
                    Spacer()
                }
                VStack(alignment:.leading,spacing: 1.0) {
                    pickerStorageType().padding(.leading, 16)
                    Rectangle().frame(maxWidth:.infinity,minHeight: 1,maxHeight: 1)
                                             .foregroundColor(.black).padding(.leading, 16)
                                             .padding(.trailing, 16)
                }.padding(.bottom,50)
                
                HStack{
                    Text("Path: ").font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)
                    Spacer()
                    Button {
                        isNameFocused = false
                        if internetMonitor.isConnected {
                            if selectedStorage == .googledrive {
                                navigationStateManager.selectionPath.append(.remoteGoogleSync)
                            } else if selectedStorage == .dropbox {
                                navigationStateManager.selectionPath.append(.remoteDropBoxSync)
                            } else if selectedStorage == .onedrive {
                                navigationStateManager.selectionPath.append(.remoteOneDriveSync)
                            }
                        }
                        else {
                            remoteFolderEditObject.remoteFolderId = UUID().uuidString
                            remoteFolderEditObject.remoteFolderPath = "LocalFolder"
                        }
                    } label: {
                        Text("Select").font(.title2).foregroundColor(.white)
                    }.frame(width: 100,height: 40).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                        .overlay {
                            RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                        }.padding(.trailing, 16)
                }
                VStack(alignment:.leading,spacing:2.0) {
                    HStack(){
                        Text(remoteFolderEditObject.remoteFolderPath).padding(.leading, 16).font(.system(size: 20, weight: .light, design: .serif)).lineLimit(nil).multilineTextAlignment(.leading)
                        Spacer()
                    }
                    Rectangle().frame(maxWidth:.infinity,minHeight: 1,maxHeight: 1)
                                             .foregroundColor(.black).padding(.leading, 16)
                                             .padding(.trailing, 16)
                }
            }.onTapGesture {
                isNameFocused = false
            }
            Spacer()
            HStack {
                Spacer()
                Button {
                    if let editionFolder: FolderItem = self.folderItem {
                        self.checkEditionAlbum(editedFolder: editionFolder)
                    } else {
                        self.checkCreationAlbum()
                    }
                } label: {
                        Text("Save").font(.title).foregroundColor(.white)
                }.frame(width: 150,height: 55).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                    .overlay {
                        RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                    }.padding(.trailing, 16)
                Spacer()
            }
        }
    }
    
    private func pickerStorageType() -> some View {
        Menu {
            Picker("File Storage", selection: $selectedStorage) {
                Text("GoogleDrive").font(.title2).tag(FolderSource.googledrive)
                    Text("DropBox").font(.title2).tag(FolderSource.dropbox)
                    Text("OneDrive").font(.title2).tag(FolderSource.onedrive)
            }.colorMultiply(.black)
        } label: {
            HStack {
                Text(folderSourceToString(selectedStorage))
                    .font(.system(size: 20, weight: .light, design: .serif)).foregroundColor(.black)
                Image(systemName: "arrowtriangle.down.fill").foregroundColor(.black)
            }
        }.id(selectedStorage)
    }
    
    private  func checkCreationAlbum() {
        if filename.isEmpty {
            creationError = NSError(domain: "Create Folder module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Folder name can't be empty."])
            isError.toggle()
            return
        }
        Task {
            do {
                try await self.coreDataController.chekDublicateAlbum(albumName: filename)
                try await self.coreDataController.createAlbum(folderItem: FolderItem(id: UUID().uuidString, localName: filename, remoteId: remoteFolderEditObject.remoteFolderId, remoteName: remoteFolderEditObject.remoteFolderPath, remoteDriveId: remoteFolderEditObject.remoteDriveId, source: selectedStorage, order: 100,nonSyncNumber: 0, totalNumber: 0))
                isCreationFinished.toggle()
                remoteFolderEditObject.clear()
                navigationStateManager.selectionPath.removeLast()
            } catch {
                creationError = error
                isError.toggle()
                return
            }
        }
    }
    
    private func checkEditionAlbum(editedFolder: FolderItem) {
        if filename.isEmpty {
            creationError = NSError(domain: "Create Folder module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Folder name can't be empty."])
            isError.toggle()
            return
        }
        if editedFolder.localName == filename {
            Task {
                   do {
                       
                       try await self.coreDataController.updateAlbums(localId: editedFolder.id, localName: editedFolder.localName, storageType: selectedStorage, newRemoteId: remoteFolderEditObject.remoteFolderId, newRemoteName: remoteFolderEditObject.remoteFolderPath, newDriveId: remoteFolderEditObject.remoteDriveId)
                       isCreationFinished.toggle()
                       remoteFolderEditObject.clear()
                       navigationStateManager.selectionPath.removeLast()
                   } catch {
                       creationError = error
                       isError.toggle()
                       return
                   }
               }
        } else {
            if remoteFolderEditObject.remoteFolderId == editedFolder.remoteId && remoteFolderEditObject.remoteFolderPath == editedFolder.remoteName {
                Task {
                    do {
                        try await self.coreDataController.chekDublicateAlbum(albumName: filename)
                        try await self.coreDataController.updateAlbums(localId: editedFolder.id, localName: editedFolder.localName, newName: filename)
                        isCreationFinished.toggle()
                        remoteFolderEditObject.clear()
                        navigationStateManager.selectionPath.removeLast()
                    } catch {
                        creationError = error
                        isError.toggle()
                        return
                    }
                }
            } else {
                Task {
                    do {
                        try await self.coreDataController.chekDublicateAlbum(albumName: filename)
                        try await self.coreDataController.updateAlbums(localId: editedFolder.id, localName: editedFolder.localName, newLocalName: filename, storageType: selectedStorage,newRemoteId: remoteFolderEditObject.remoteFolderId, newRemoteName: remoteFolderEditObject.remoteFolderPath,newDriveId: remoteFolderEditObject.remoteDriveId)
                        isCreationFinished.toggle()
                        remoteFolderEditObject.clear()
                        navigationStateManager.selectionPath.removeLast()
                    } catch {
                        creationError = error
                        isError.toggle()
                        return
                    }
                }
            }
        }
    }
    
    private func isChangesHasBeenMade() -> Bool {
        if let editableItem: FolderItem = self.folderItem {
            if selectedStorage == editableItem.folderSource && filename == editableItem.localName
                && remoteFolderEditObject.remoteFolderId == editableItem.remoteId && remoteFolderEditObject.remoteFolderPath == editableItem.remoteName
                && remoteFolderEditObject.remoteDriveId == editableItem.remoteDriveId {
                return false
            }
        } else {
            if filename.isEmpty && remoteFolderEditObject.remoteFolderId.isEmpty && remoteFolderEditObject.remoteFolderPath.isEmpty && remoteFolderEditObject.remoteDriveId.isEmpty && selectedStorage == .googledrive {
                return false
            }
        }
        return true
    }
    private func resetToInitialValues() {
        if let editableItem: FolderItem = self.folderItem {
            filename = editableItem.localName
            remoteFolderEditObject.remoteFolderId = editableItem.remoteId
            remoteFolderEditObject.remoteFolderPath = editableItem.remoteName
            remoteFolderEditObject.remoteDriveId = editableItem.remoteDriveId
        }
        creationError = nil
    }
    
    private func loadingOnAppear() {
        guard let editedFolderId: String = self.albumId, let editedFolderName: String = self.folderName else {
            isOnStack = true
            return
        }
        Task {
            do {
                let albumItem: FolderItem = try await coreDataController.findAlbum(albumId: editedFolderId)
                if albumItem.localName != editedFolderName {
                    throw NSError(domain: "Edit Folder module", code: 2000, userInfo: [NSLocalizedDescriptionKey: "Loaded folder name is not equal to \(editedFolderName)."])
                }
                self.folderItem = albumItem
                guard let editedFolder: FolderItem = self.folderItem else {
                    return
                }
                filename = editedFolder.localName
                selectedStorage = editedFolder.folderSource
                remoteFolderEditObject.remoteFolderId = editedFolder.remoteId
                remoteFolderEditObject.remoteFolderPath = editedFolder.remoteName
                remoteFolderEditObject.remoteDriveId = editedFolder.remoteDriveId
                print("remotePath: \(remoteFolderEditObject.remoteFolderPath)")
                isOnStack = true
                
            } catch {
                isOnStack = true
                creationError = error
                isError.toggle()
                return
            }
        }

    }
}
/*
struct CreateFolderModalWithPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CreateFolderModalWithPickerView( coreDataController: SyncAssetDatabaseAccessObject())
    }
}*/
