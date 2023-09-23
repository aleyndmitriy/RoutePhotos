//
//  AssetRow.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.08.2022.
//

import SwiftUI

struct AssetRow: View {
    var photoListPresenter: PhotoListPresenter
    @Binding var photoItem: ImageProperties
    var body: some View {
        HStack {
            CircleImage(image: photoItem.image)
                        .frame(width: 70, height: 70)
                
            VStack(alignment:.leading, spacing: 1.0) {
                Text(photoItem.date, formatter: dateFotmatter()).font(.system(size: 16, weight: .light, design: .serif))
                if photoItem.address.isEmpty {
                    Text("Unknown").font(.system(size: 10, weight: .light, design: .serif))
                } else {
                    Text(photoItem.address).font(.system(size: 10, weight: .light, design: .serif))
                }
                
            }
            
              Spacer()
            imageStatus()
        }
    }
    private func imageStatus() -> some View {
        HStack {
            switch photoItem.status {
            case .local:
                Image("iredcircle").resizable().frame(width: 15,height: 15,alignment: .center)
            case .pending:
                Image("iwhitecircle").resizable().frame(width: 15,height: 15,alignment: .center)
            case .synchronized:
                Image("igreencircle").resizable().frame(width: 15,height: 15,alignment: .center)
            }
        }
    }
}

struct AssetRow_Previews: PreviewProvider {
    static let presenter = PhotoListPresenter()
    static var previews: some View {
        AssetRow(photoListPresenter: presenter, photoItem: .constant(ImageProperties(image: Image("chincoteague"))))
    }
    
}
