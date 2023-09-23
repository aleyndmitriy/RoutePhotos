//
//  AssetsTabView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 18.01.2023.
//

import SwiftUI

struct AssetsTabView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    var photoListPresenter: PhotoListPresenter
    var coreDataController = SyncAssetDatabaseAccessObject()
    let albumId: String
    let albumName: String
    @State private var tabs = [UUID]()
    @State var selectedTab: UUID
    @State private var isProcessing: Bool = false
    @State private var loadingError: Error?
    var body: some View {
        Grid {
            if isProcessing {
                VStack {
                    ProgressView {
                        Text("Loading...").padding(.trailing, 16).padding(.leading, 16).foregroundColor(.gray)
                    }.background(.white)
                    Text("This process may take a few seconds").padding(.trailing, 16).padding(.leading, 16).foregroundColor(.gray).background(.white)
                }.background(.white)
            } else {
                VStack(spacing: 5) {
                    TabView(selection: $selectedTab) {
                        ForEach(tabs, id: \.self ) { tab in
                            AssetDetailView(photoListPresenter: photoListPresenter, tabs: $tabs, selectedTab: $selectedTab, albumId: albumId, albumName: albumName, photoId: tab).tag(tab)
                        }
                    }.transition(.slide).tabViewStyle(.page)
                    bottomView().frame(idealWidth: .infinity, idealHeight: 60)
                }
            }
        }.onAppear(perform: {
            loadItems()
        }).background(Color(red: 192.0/255.0, green: 239.0/255.0, blue: 239.0/255.0))
    }
    private func bottomView()-> some View {
            HStack {
                Button {
                    if let currentIndex: Int = tabs.firstIndex(where: { (currentId:UUID) in
                        return currentId == selectedTab
                    }), currentIndex > 0 {
                        withAnimation {
                            selectedTab = tabs[currentIndex - 1]
                        }
                    }
                } label: {
                    HStack{
                        Image(systemName: "arrow.left.circle").resizable().frame(width: 25,height: 25).foregroundColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                        Text("Previous").foregroundColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                    }
                    
                }.padding(.leading, 15)
                Spacer()
                menuStorageType()
                Spacer()
                Button {
                    if let currentIndex: Int = tabs.firstIndex(where: { (currentId:UUID) in
                        return currentId == selectedTab
                    }), currentIndex < tabs.count - 1 {
                        withAnimation {
                            selectedTab = tabs[currentIndex + 1]
                        }
                    }
                } label: {
                    HStack{
                        Text("Next").foregroundColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                        Image(systemName: "arrow.right.circle").resizable().frame(width: 25,height: 25).foregroundColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                    }
                    
                }.padding(.trailing, 15)

            }.background(Color(red: 192.0/255.0, green: 239.0/255.0, blue: 239.0/255.0)).padding(.top, 5)
        }
    
    private func menuStorageType() -> some View {
        Menu {
            Button {
                navigationStateManager.selectionPath.append(.editPicture(albumId, albumName, selectedTab))
            } label: {
                Label {
                    Text("Edit File Name").font(.title2)
                } icon: {
                    Image(systemName: "pencil")
                }
            }
            
            Button {
                navigationStateManager.selectionPath.append(.addComment(albumId, albumName, selectedTab))
            } label: {
                Label {
                    Text("Add Comment").font(.title2)
                } icon: {
                    Image(systemName: "pencil.tip")
                }
            }
        }label: {
            Label {
                Text("").font(.title2)
            } icon: {
                Image(systemName: "ellipsis.circle").resizable().frame(width: 25,height: 25).foregroundColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
            }
        }
    }
    private func loadItems() {
        isProcessing.toggle()
        self.tabs.removeAll()
        Task {
            do {
                let albumItem: FolderItem = try await coreDataController.findAlbum(albumId: albumId)
                self.tabs = try  await photoListPresenter.loadIdsPhotoFromAlbum(albumId: albumItem.id, albumName: albumItem.localName)
                isProcessing.toggle()
            } catch {
                loadingError = error
                isProcessing.toggle()
            }
        }
    }
}

struct AssetsTabView_Previews: PreviewProvider {
    static var previews: some View {
        AssetsTabView(photoListPresenter: PhotoListPresenter(), albumId: "Id",albumName: "Name", selectedTab: UUID())
    }
}
