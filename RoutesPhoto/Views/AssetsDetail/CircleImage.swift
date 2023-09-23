//
//  CircleImage.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 20.06.2022.
//

import SwiftUI

struct CircleImage: View {
    var image: Image
    var body: some View {
        image
            .resizable()
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 15)))
            /*.overlay {
                RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
            }*/
            .shadow(radius: 6)
            //.scaledToFit()
           
    }
}

struct CircleImage_Previews: PreviewProvider {
    static var previews: some View {
        CircleImage(image: Image("chincoteague"))
    }
}
