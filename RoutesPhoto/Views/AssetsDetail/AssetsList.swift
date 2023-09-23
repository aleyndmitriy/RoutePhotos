//
//  AssetsList.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.08.2022.
//

import SwiftUI

struct AssetsList: View {
    @EnvironmentObject var internetMonitor: NetworkMonitor
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    let columns = [GridItem(.adaptive(minimum: 100,maximum: 120)), GridItem(.adaptive(minimum: 100,maximum: 120)), GridItem(.adaptive(minimum: 100,maximum: 120))]
   let photoListPresenter: PhotoListPresenter
    var coreDataController = SyncAssetDatabaseAccessObject()
    @State private var editMode: EditMode = .inactive
    @State private var selectMode: SelectMode = .inactive
    @State private var multiSelection: Set<UUID> = []
    @State private var isGridView: Bool = true
    @State private var isProcessing: Bool = false
    @State private var loadingError: Error?
    @State private var isConfirming = false
    @State private var dialogDetail: ImageProperties?
    @State private var currentPhotos: [ImageProperties] = [ImageProperties]()
    let albumId: String
    @State var folderName: String = String()
    
    var body: some View {
        Grid {
            if let err: Error = loadingError {
                VStack {
                    Spacer()
                    Text(err.localizedDescription).font(.title3)
                    Button {
                        resetStates()
                        loadItems()
                    } label: {
                        Text("Try again").font(.title2).foregroundColor(.white)
                    }.frame(width: 100,height: 40).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                        .overlay {
                            RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                        }.padding(.trailing, 16)
                    Spacer()
                }
            } else {
                    VStack(spacing: 0.0) {
                        if isGridView {
                            mainGridViewPlace()
                        } else {
                            mainViewPlace()
                        }
                    }.background(Color(red: 192.0/255.0, green: 239.0/255.0, blue: 239.0/255.0)).onDisappear{
                        editMode = .inactive
                    }
            }
        }.navigationBarBackButtonHidden().navigationTitle(folderName).toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        navigationStateManager.selectionPath.removeLast()
                    } label: {
                        Image(systemName: "chevron.left")
                    }.frame(minWidth: 30.0, maxWidth: 30.0).buttonStyle(.plain).foregroundColor(.blue)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    menuStorageType()
                    Button {
                        navigationStateManager.selectionPath.append(.photoLibrary(albumId, folderName))
                    } label: {
                        Image(systemName: "doc.badge.plus").resizable().frame(width: 25,height: 25).foregroundColor(.black)
                    }
                }
            }
        }
        
        
                            
    }
    
    private func menuStorageType() -> some View {
        Menu {
            Button {
                if internetMonitor.isConnected {
                    navigationStateManager.selectionPath.append(.editFolder(albumId, folderName))
                }
            } label: {
                Label {
                    Text("Edit").font(.title2)
                } icon: {
                    Image(systemName: "pencil")
                }
            }

            Button {
                multiSelection.removeAll()
                editMode = .inactive
                isGridView.toggle()
            } label: {
                if isGridView {
                    Label {
                        Text("ListView").font(.title2)
                    } icon: {
                        Image(systemName: "list.bullet")
                    }
                } else {
                    Label {
                        Text("GridView").font(.title2)
                    } icon: {
                        Image(systemName: "square.grid.4x3.fill")
                    }
                }
                
            }
        } label: {
            Label {
                Text("").font(.title2)
            } icon: {
                Image(systemName: "ellipsis").rotationEffect(.degrees(90)).frame(width: 30,height: 30).foregroundColor(.black)
            }
        }
    }

    private func mainViewPlace() -> some View {
        Grid {
            if isProcessing {
                ProgressView {
                    Text("Loading...").foregroundColor(.black).background(.white)
                }.background(.white)
            } else {
                List(selection:$multiSelection) {
                    ForEach($currentPhotos) { item in
                        Button {
                            navigationStateManager.selectionPath.append(.photoDetail(albumId, folderName, item.wrappedValue.id))
                        } label: {
                            AssetRow(photoListPresenter: photoListPresenter, photoItem: item)
                        }.disabled(editMode == .active).swipeActions {
                            Button(role: .destructive) {
                                dialogDetail = item.wrappedValue
                            } label: {
                                Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }.background(.white).environment(\.editMode, $editMode).listStyle(.plain).sheet(item:$dialogDetail,  onDismiss: didDismiss) { detail in
                    VStack {
                        Spacer()
                        Text("Are you sure?").font(.system(size: 18, weight: .semibold, design: .serif))
                        Text("Picture \"\(detail.name)\" will be removed.").font(.system(size: 20, weight: .light, design: .serif)).padding(.leading, 16)
                            .padding(.trailing, 16)
                        Spacer()
                        HStack{
                            Button {
                                deletePhoto(photoId: detail.id)
                            } label: {
                                Text("Remove").font(.title2).foregroundColor(.white)
                            }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                .overlay {
                                    RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                }
                            Button {
                                dialogDetail = nil
                            } label: {
                                Text("Cancel").font(.title2).foregroundColor(.white)
                            }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                .overlay {
                                    RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                }
                        }
                    }.preferredColorScheme(.light)
                }
            }
        }.onAppear {
            loadItems()
        }
    }
    
    private func mainGridViewPlace() -> some View {
        Grid {
            if isProcessing {
                ProgressView {
                    Text("Loading...").foregroundColor(.black).background(.white)
                }.background(.white)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns:columns,alignment: .center) {
                        ForEach($currentPhotos) { item in
                            Button {
                                navigationStateManager.selectionPath.append(.photoDetail(albumId, folderName, item.wrappedValue.id))
                            } label: {
                                ChooseLibrariesPhotosView(multiSelection: $multiSelection, editionMode: $editMode, item: item).frame(minWidth:100,maxWidth: 120,minHeight: 100,maxHeight: 120)
                            }.disabled(editMode == .active).simultaneousGesture(TapGesture().onEnded {
                                if editMode != .active {
                                    return
                                }
                                if multiSelection.contains(item.id) {
                                    multiSelection.remove(item.id)
                                } else {
                                    multiSelection.insert(item.id)
                                }
                            }
                            )
                        }
                    }.padding(.leading,5).padding(.trailing, 5).padding(.top,5)
                }.background(.white)
            }
        }.onAppear {
            loadItems()
        }
    }
    
    
    private func loadItems() {
        isProcessing.toggle()
        self.currentPhotos.removeAll()
        Task {
            do {
                let albumItem: FolderItem = try await coreDataController.findAlbum(albumId: albumId)
                let photoProperties: [ImageProperties] = try  await photoListPresenter.loadPhotoFromAlbum(albumId: albumItem.id, albumName: albumItem.localName)
                self.currentPhotos = photoProperties
                folderName = albumItem.localName
                isProcessing.toggle()
            } catch {
                loadingError = error
                isProcessing.toggle()
            }
        }
    }
    
    private func deletePhoto(photoId: UUID) {
        dialogDetail = nil
        isProcessing.toggle()
        Task {
            do {
                try await photoListPresenter.deletePhoto(albumId: albumId, albumName: folderName, photoId: photoId)
                let photoProperties: [ImageProperties] = try  await photoListPresenter.loadPhotoFromAlbum(albumId: albumId, albumName: folderName)
                self.currentPhotos = photoProperties
                isProcessing.toggle()
            } catch {
                loadingError = error
                isProcessing.toggle()
            }
        }
    }
    
    private func deletePhotos(ids: [UUID]) {
        isProcessing.toggle()
        Task {
            do {
                try await photoListPresenter.deletePhotos(albumId: albumId, albumName: folderName, photosIds:ids)
                let photoProperties: [ImageProperties] = try  await photoListPresenter.loadPhotoFromAlbum(albumId: albumId, albumName: folderName)
                self.currentPhotos = photoProperties
                isProcessing.toggle()
                editMode = .inactive
            } catch {
                loadingError = error
                isProcessing.toggle()
                editMode = .inactive
            }
        }
    }
    
    private func resetStates() {
        loadingError = nil
        isProcessing = false
        currentPhotos.removeAll()
    }
    
    func didDismiss() {
            
    }
}

struct AssetsList_Previews: PreviewProvider {
    static var previews: some View {
        AssetsList(photoListPresenter: PhotoListPresenter(), albumId: "id", folderName: "Name")
    }
}
