//
//  RootLibraryRowView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 19.08.2022.
//

import SwiftUI

struct RootLibraryRowView: View {
    @EnvironmentObject var internetMonitor: NetworkMonitor
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    var coreDataController: SyncAssetDatabaseAccessObject
    @State var connectionFailAlert: Bool = false
    @Binding var folderItem: FolderItem
    var body: some View {
        HStack(alignment: .center, spacing: 10, content: {
            switch folderItem.folderSource {
            case .googledrive:
                self.createButton(iconTypeName: "googledrive")
            case .onedrive:
                self.createButton(iconTypeName: "onedrive")
            case .dropbox:
                self.createButton(iconTypeName: "dropbox")
            }
            Text(folderItem.localName).font(.system(size: 18, weight: .light, design: .serif))
            Spacer()
            Text("\(folderItem.totalNumber)").font(.system(size: 18, weight: .light, design: .serif))
            Button {
                navigationStateManager.selectionPath.append(.photoList(folderItem.id))
            } label: {
                Image(systemName: "chevron.right")
            }.frame(minWidth: 30.0, maxWidth: 40.0).buttonStyle(.plain)
        }).onAppear {
            
        }
    }
    
    private func createButton(iconTypeName: String)-> some View {
        ZStack {
            ButtonFolderView(folderItem: $folderItem,  iconTypeName: iconTypeName)
            Button {
                navigationStateManager.selectionPath.append(.camera(folderItem.id, folderItem.localName))
            } label: {
                EmptyView()
            }.opacity(0.0).frame(maxWidth: 8.0, maxHeight: 8.0)

            }
    }
}



struct RootLibraryRowView_Previews: PreviewProvider {
    static var previews: some View {
        RootLibraryRowView( coreDataController: SyncAssetDatabaseAccessObject(),folderItem: .constant(FolderItem(id: UUID().uuidString, localName: "GoogleDriveFolder", remoteId: UUID().uuidString, remoteName: "", source: FolderSource.googledrive, order: 0,nonSyncNumber: 4,totalNumber: 10)))
    }
}
