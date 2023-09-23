//
//  RootLibraryView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 17.08.2022.
//

import SwiftUI
import Photos
import GoogleSignIn



struct RootLibraryView: View {
    @EnvironmentObject var internetMonitor: NetworkMonitor
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    var coreDataController = SyncAssetDatabaseAccessObject()
    @State var albums = [FolderItem]()
    @State var loadingError: Error?
    @State var isError: Bool = false
    @State var isLoading: Bool = false
    @State var isCreateWithoutNet: Bool = false
    @State private var dialogDetail: FolderItem?
    var body: some View {
            VStack {
                if albums.isEmpty {
                    emptyListView()
                } else {
                    listView()
                }
            }.sheet(item:$dialogDetail,  onDismiss: didDismiss) { detail in
                VStack {
                    Spacer()
                    Text("Are you sure?").font(.system(size: 18, weight: .semibold, design: .serif))
                    Text("Folder \"\(detail.localName)\" and its contents will be removed.").font(.system(size: 20, weight: .light, design: .serif)).padding(.leading, 16)
                        .padding(.trailing, 16)
                    Spacer()
                    HStack {
                        Button {
                            deleteFolderItem(folder: detail)
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
                    Spacer()
                }.preferredColorScheme(.light)
            }.navigationBarBackButtonHidden().navigationTitle("RoutesPhoto").toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                                    Button {
                                        navigationStateManager.selectionPath.append(.settings)
                                    } label: {
                                        Image(systemName: "slider.horizontal.3").resizable().frame(width: 30, height: 25)
                                            .foregroundColor(.black)
                                    }
                                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            Synchronizer.shared.Sync()
                            
                        } label: {
                            Image(systemName: "square.and.arrow.up").resizable().frame(width: 25,height: 25).foregroundColor(.black)
                        }
                        Button {
                            navigationStateManager.selectionPath.append(.addFolder)
                        } label: {
                            Image(systemName: "plus").resizable().frame(width: 25, height: 25, alignment: .center).foregroundColor(.black)
                        }
                    }
                                    }
            }.onAppear {
                albums.removeAll()
                loadItems()
            }.navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
    }
    
    private func emptyListView() -> some View {
        VStack(spacing: 10) {
            Image("mainViewFolder").resizable().frame(width: 150,height: 150)
            Text("You don't have any folder yet").font(.title3)
            Button {
                if internetMonitor.isConnected {
                    navigationStateManager.selectionPath.append(.addFolder)
                }
            } label: {
                Text("Create new folder").font(.title2).foregroundColor(.white)
            }.frame(width: 275,height: 65).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 30, height: 30)))
                .overlay {
                    RoundedRectangle(cornerSize: CGSize(width:30, height: 30)).stroke(.white, lineWidth: 3)
                }.padding(.trailing, 16).padding(.top,50)
        }
        
    }
    
    private func listView()-> some View {
        List {
            ForEach($albums) { item in
                        RootLibraryRowView(coreDataController: coreDataController,  folderItem: item).environmentObject(internetMonitor)
                    .swipeActions {
                        Button(role: .destructive) {
                            dialogDetail = item.wrappedValue
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            if internetMonitor.isConnected {
                                navigationStateManager.selectionPath.append(.editFolder(item.wrappedValue.id, item.wrappedValue.localName))
                            }
                            
                        } label: {
                            Label {
                                Text("Edit").font(.title2)
                            } icon: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
            }
        }.listStyle(PlainListStyle())
    }
    
    private func loadItems() {
        isLoading.toggle()
        Task {
            do {
                self.albums.removeAll()
                self.albums = try  await coreDataController.loadAlbums()
                isLoading.toggle()
            } catch {
                loadingError = error
                isLoading.toggle()
                isError.toggle()
            }
        }
    }
    
    private func deleteFolderItem(folder: FolderItem) {
        dialogDetail = nil
        isLoading.toggle()
        Task {
            do {
                try await coreDataController.deleteAlbums(localId: folder.id, localName: folder.localName)
                self.albums = try  await coreDataController.loadAlbums()
                isLoading.toggle()
            } catch {
                loadingError = error
                isLoading.toggle()
                isError.toggle()
            }
        }
    }
    
    private func resetStates() {
        loadingError = nil
        isLoading = false
        isError = false
        albums.removeAll()
    }
    
    func didDismiss() {
            
    }
    
    init() {
      let coloredAppearance = UINavigationBarAppearance()
        let backButtonAppearance = UIBarButtonItemAppearance(style: .plain)
        backButtonAppearance.focused.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.disabled.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        coloredAppearance.backButtonAppearance = backButtonAppearance
      coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = UIColor(red: 192.0/255.0, green: 239.0/255.0, blue: 239.0/255.0, alpha: 1.0)
        UINavigationBar.appearance().standardAppearance = coloredAppearance
          UINavigationBar.appearance().compactAppearance = coloredAppearance
          UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
       UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .black
    UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).backgroundColor = .white
        
    }
}

struct RootLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        RootLibraryView().environmentObject(NetworkMonitor.shared)
    }
}
