//
//  FrameView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.06.2022.
//

import SwiftUI

struct FrameView: View {
    var image: CGImage?
    private let label = Text("Video feed")
    
    var body: some View {
        if let img: CGImage = image {
          GeometryReader { geometry in
            Image(img, scale: 1.0, orientation: .upMirrored, label: label)
              .resizable()
              .scaledToFill()
              .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .center)
              .clipped()
          }
        } else {
          EmptyView()
        }
    }
}

struct FrameView_Previews: PreviewProvider {
    static var previews: some View {
        FrameView(image: nil)
    }
}
