//
//  ChooseLibrariesPhotosView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 17.10.2022.
//

import SwiftUI

struct ChooseLibrariesPhotosView: View {
    @Binding var multiSelection: Set<UUID>
    @Binding var editionMode: EditMode
    @Binding var item: ImageProperties
    var body: some View {
            ZStack {
                item.image.resizable()
                    VStack {
                        Spacer()
                        HStack {
                            VStack(spacing: 1.0) {
                                Text(item.date, formatter: dateFotmatter()).font(.system(size: 12, weight: .light, design: .serif)).foregroundColor(.white)
                                if item.address.isEmpty {
                                    Text("Unknown").font(.system(size: 8, weight: .light, design: .serif)).foregroundColor(.white)
                                } else {
                                    Text(item.address).font(.system(size: 8, weight: .light, design: .serif)).foregroundColor(.white)
                                }
                            }
                            switch item.status {
                            case .local:
                                Image("iredcircle").resizable().frame(width: 15,height: 15,alignment: .center)
                            case .pending:
                                Image("iwhitecircle").resizable().frame(width: 15,height: 15,alignment: .center)
                            case .synchronized:
                                Image("igreencircle").resizable().frame(width: 15,height: 15,alignment: .center)
                            }
                            Image(systemName: "checkmark.circle.fill").foregroundColor(Color(white: 0.75)).clipShape(Circle()).overlay {
                                Circle().stroke(.white, lineWidth: 2)
                            }.opacity(multiSelection.contains(item.id) ? 1.0 : 0.0)
                        }
                    }
            }
    }
    
}

