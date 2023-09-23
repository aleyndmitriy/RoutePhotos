//
//  AssetDetailView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 22.08.2022.
//

import SwiftUI
import CoreLocation

struct AssetDetailView: View {
    class UUIDExt: Identifiable {
        let id: UUID
        init(id: UUID) {
            self.id = id
        }
    }
    
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    var photoListPresenter: PhotoListPresenter
    @State private var photoImage: Image?
    @State private var photoName: String = String()
    @State private var photoStatus: PhotoStatus = .local
    @State private var locAddress: String = String()
    @State private var photoDate: Date = Date()
    @State private var isProcessing: Bool = false
    @State private var dialogDetailId: UUIDExt?
    @Binding var tabs: [UUID]
    @Binding var selectedTab: UUID
    let albumId: String
    let albumName: String
    let photoId: UUID
    
    @State private var isUploading: Bool = false
    
    var body: some View {
            VStack(spacing: 0.0) {
                titleView().frame(height: 70)
                mainView().sheet(item:$dialogDetailId, onDismiss: didDismiss) { detail in
                    VStack {
                        Spacer()
                        Text("Are you sure?").font(.system(size: 18, weight: .semibold, design: .serif))
                        Text("Picture \"\(photoName)\" will be removed.").font(.system(size: 20, weight: .light, design: .serif)).padding(.leading, 16)
                            .padding(.trailing, 16)
                        Spacer()
                        HStack{
                            Button {
                                deletePhoto(photoId: detail.id)
                            } label: {
                                Text("Remove").font(.title2).foregroundColor(.white)
                            }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                .overlay {
                                    RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                }
                            Button {
                                dialogDetailId = nil
                            } label: {
                                Text("Cancel").font(.title2).foregroundColor(.white)
                            }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                .overlay {
                                    RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                }
                        }
                    }.preferredColorScheme(.light)
                }
                Text(photoName).font(.system(size: 14, weight: .light, design: .serif))
            }.background(Color(red: 192.0/255.0, green: 239.0/255.0, blue: 239.0/255.0)).toolbar(.hidden)
    }
    private func titleView()-> some View {
        HStack(spacing: 5) {
            Button {
                navigationStateManager.selectionPath.removeLast()
            } label: {
                Image(systemName: "chevron.left")
            }.frame(minWidth: 30.0, maxWidth: 40.0).buttonStyle(.plain).foregroundColor(.blue)
            VStack(spacing: 0) {
                Text(albumName).font(.system(size: 20, weight: .light, design: .serif)).lineLimit(nil).multilineTextAlignment(.leading)
                HStack(spacing: 0.0) {
                    Text(photoDate, formatter: dateFotmatter()).padding(.trailing, 15)
                    Spacer()
                    imageStatus().padding(.trailing,5)
                }
                HStack {
                    Text(locAddress).font(.system(size: 14, weight: .light, design: .serif))
                    Spacer()
                }
            }
            Button {
                dialogDetailId = UUIDExt(id: photoId)
            } label: {
                Image("custom_trash").resizable().frame(width: 30,height: 40).foregroundColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
            }.padding(.trailing, 16)
        }.background(Color(red: 192.0/255.0, green: 239.0/255.0, blue: 239.0/255.0))
    }
    private func mainView() -> some View {
        Grid {
            if let img: Image = photoImage {
                GeometryReader { proxy in
                    img.resizable()
                          .scaledToFit()
                          .frame(
                            width: proxy.size.width, height: proxy.size.height)
                          .clipShape(Rectangle()).modifier(ImageModifier(contentSize: CGSize(width: proxy.size.width, height: proxy.size.height)))
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView {
                        Text("Loading...").padding(.trailing, 16).padding(.leading, 16).foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }.onAppear(perform: loadImage).onDisappear{
            photoImage = nil
        photoName = String()
        }
    }
    
    private func loadImage() {
        Task {
            do {
                let photoItem: ImageProperties = try await photoListPresenter.loadCurrentPhotoFromAlbum(albumId: albumId, albumName: albumName, photoId: photoId)
                photoImage = photoItem.image
                photoDate = photoItem.date
                locAddress = photoItem.address
                photoStatus = photoItem.status
                photoName = photoItem.name
                if locAddress.isEmpty {
                    locAddress = try await photoListPresenter.updateAddressPhoto(albumId: albumId, albumName: albumName,  photo: photoItem)
                }
                if locAddress.isEmpty {
                    locAddress = "Unknown"
                }
            } catch {
               
            }
        }
        
    }
    
    private func imageStatus() -> some View {
        HStack {
            switch photoStatus {
            case .local:
                Image("iredcircle").resizable().frame(width: 15,height: 15,alignment: .center)
            case .pending:
                Image("iwhitecircle").resizable().frame(width: 15,height: 15,alignment: .center)
            case .synchronized:
                Image("igreencircle").resizable().frame(width: 15,height: 15,alignment: .center)
            }
        }
    }
    private func deletePhoto(photoId: UUID) {
        dialogDetailId = nil
        isProcessing.toggle()
        Task {
            do {
                try await photoListPresenter.deletePhoto(albumId: albumId, albumName: albumName, photoId: photoId)
                if let currentIndex: Int = tabs.firstIndex(where: { (currentId:UUID) in
                    return currentId == selectedTab
                }){
                    if currentIndex > 0 && currentIndex < tabs.count {
                        selectedTab = tabs[currentIndex - 1]
                    } else {
                        if tabs.count > 1 {
                            selectedTab = tabs[tabs.count - 1]
                        } else {
                            navigationStateManager.selectionPath.removeLast()
                        }
                    }
                    tabs.remove(at: currentIndex)
                }
                isProcessing.toggle()
            } catch {
                isProcessing.toggle()
            }
        }
    }
    
    func didDismiss() {
            
    }
}

struct AssetDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AssetDetailView(photoListPresenter: PhotoListPresenter(), tabs: .constant([UUID]()), selectedTab: .constant(UUID()), albumId: "Id", albumName: "Name", photoId: UUID())
    }
}
