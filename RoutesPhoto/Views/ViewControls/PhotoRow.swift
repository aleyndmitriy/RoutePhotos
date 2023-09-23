//
//  PhotoRow.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 20.06.2022.
//

import SwiftUI

struct PhotoRow: View {
    @State private var photoImage: Image?
    var photoItem: PhotoItem
    var body: some View {
        HStack {
            if let image: Image = self.photoImage {
                CircleImage(image: image)
                    .frame(width: 80, height: 80)
            }
            if let date: Date = photoItem.timestamp {
                Text(date, formatter: itemFormatter)
            }
            Spacer()
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        guard let data: Data = self.photoItem.image, let uiImage: UIImage = UIImage(data: data) else {
            return
        }
        self.photoImage =  Image(uiImage: uiImage)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct PhotoRow_Previews: PreviewProvider {
    static var previews: some  View {
        PhotoRow(photoItem: PersistenceController.photoDetailPreview)
    }
}
