//
//  MessageRowView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 26.01.2023.
//

import SwiftUI

struct MessageRowView: View {
    var photoListPresenter: PhotoListPresenter
    @Binding var message: MessageProperties
    var body: some View {
        GroupBox(label: Text(message.name).font(.system(size: 14, weight: .light, design: .serif))) {
            imageStatus()
            HStack{
                Text(message.text).padding(.top, 8).font(.footnote)
                Spacer()
            }
        }
    }
    
    private func imageStatus() -> some View {
        HStack {
            Text(message.date, formatter: dateFotmatter())
            Spacer()
            switch message.status {
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

struct MessageRowView_Previews: PreviewProvider {
    static var previews: some View {
        MessageRowView(photoListPresenter: PhotoListPresenter(), message: .constant(MessageProperties(id: UUID(), photoId: UUID().uuidString, name: "PhotoName", text: "SomeText", date: Date(), status: PhotoStatus.local)))
    }
}
