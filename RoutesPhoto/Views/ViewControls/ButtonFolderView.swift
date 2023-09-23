//
//  ButtonFolderView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 03.10.2022.
//

import SwiftUI

struct ButtonFolderView: View {
    @Binding var folderItem: FolderItem
    var iconTypeName: String
    
    var body: some View {
        HStack {
            Image(iconTypeName).resizable().frame(width: 12, height: 12, alignment: .center)
            if folderItem.totalNumber > 0 {
                if folderItem.nonSyncNumber > 0 {
                    Image("folder_red").resizable().frame(width: 30, height: 25, alignment: .center).overlay(alignment: .center) {
                        Text("\(folderItem.nonSyncNumber)").font(.system(size: 14, weight: .light, design: .default)).foregroundColor(.white).offset(CGSize(width: 0.0, height: 3.0))
                    }
                } else {
                    Image("folder_green").resizable().frame(width: 30, height: 25, alignment: .center)
                }
            } else {
                Image("folder_green").resizable().frame(width: 30, height: 25, alignment: .center)
            }
        }
        
    }
    
}

struct ButtonFolderView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonFolderView(folderItem: .constant(FolderItem(id: UUID().uuidString, localName: "GoogleDriveFolder", remoteId: UUID().uuidString, remoteName: "", source: FolderSource.googledrive, order: 0,nonSyncNumber: 4,totalNumber: 10)), iconTypeName: "g.circle.fill")
    }
}
