//
//  EditButton.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 03.11.2022.
//

import SwiftUI

struct EditButton: View {
    @Binding var editMode: EditMode
    var action: () -> Void = {}
    var body: some View {
        Button {
            withAnimation {
                if editMode == .active {
                    action()
                    editMode = .inactive
                } else {
                    editMode = .active
                }
            }
        } label: {
            if editMode == .active {
                Text("Cancel").font(.title2)
            } else {
                Label {
                    Text("Edit").font(.title2)
                } icon: {
                    Image(systemName: "pencil")
                }
            }
        }
    }
}

struct EditButton_Previews: PreviewProvider {
    static var previews: some View {
        EditButton(editMode: .constant(.inactive))
        EditButton(editMode: .constant(.active))
        EditButton(editMode: .constant(.transient))
    }
}
