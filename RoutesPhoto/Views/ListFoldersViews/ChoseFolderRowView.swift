//
//  ChoseFolderRowView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 06.10.2022.
//

import SwiftUI

struct ChoseFolderRowView: View {
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    @Binding var selectedItem: String?
    @Binding var isSyncFinished: Bool
    @State var isExpand: Bool = false
    let level: Int
    let itemId: String
    let text: String
    var body: some View {
        HStack {
            Text(text).padding(.leading, CGFloat(level*16))
            Spacer()
            Button {
                selectedItem = itemId
                isExpand.toggle()
                if isExpand {
                    isSyncFinished.toggle()
                } else {
                    remoteFolderEditObject.collapseCell(itemId: itemId)
                }
            } label: {
                if isExpand {
                    Image(systemName: "chevron.down")
                } else {
                    Image(systemName: "chevron.right")
                }
            }.padding(.trailing, 16).buttonStyle(BorderlessButtonStyle())
        }
    }
}

struct ChoseFolderRowView_Previews: PreviewProvider {
    static var previews: some View {
        ChoseFolderRowView(remoteFolderEditObject: RemoteFolderEditObject(), selectedItem: .constant("some"), isSyncFinished: .constant(false), level: 3, itemId: UUID().uuidString, text: "Sometext")
    }
}
