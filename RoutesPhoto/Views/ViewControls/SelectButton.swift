//
//  SelectButton.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 03.11.2022.
//

import SwiftUI

enum SelectMode {
    case active, inactive

    var isActive: Bool {
        self == .active
    }

    mutating func toggle() {
        switch self {
        case .active:
            self = .inactive
        case .inactive:
            self = .active
        }
    }
}

struct SelectButton: View {
    @Binding var mode: SelectMode
    var action: () -> Void = {}
    var body: some View {
        Button {
            withAnimation {
                mode.toggle()
                action()
            }
        } label: {
            Text(mode.isActive ? "Deselect All" : "Select All").foregroundColor(.black)
        }
    }
}

struct SelectButton_Previews: PreviewProvider {
    static var previews: some View {
        SelectButton(mode: .constant(.active))
        SelectButton(mode: .constant(.inactive))
    }
}
