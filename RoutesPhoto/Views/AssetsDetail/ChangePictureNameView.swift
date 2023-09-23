//
//  ChangePictureNameView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 24.01.2023.
//

import SwiftUI
import Combine

struct ChangePictureNameView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    var photoListPresenter: PhotoListPresenter
    let folderId: String
    let folderName: String
    let pictureId: UUID
    @State private var oldName: String = String()
    @State private var newName: String = String()
    @State private var isProcessing: Bool = false
    @State private var savingError: Error?
    @FocusState var isNameFocused : Bool
    var body: some View {
        Grid {
            if isProcessing {
                ProgressView("Saving...")
                Text("This process may take a few seconds").padding(.trailing, 16).padding(.leading, 16).foregroundColor(.gray)
                Spacer()
            } else {
                if let err: Error = savingError {
                    VStack {
                        Spacer()
                        Text(err.localizedDescription)
                        Spacer()
                        Button {
                            savingError = nil
                        } label: {
                            Text("Ok").font(.title2).foregroundColor(.white)
                        }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                            .overlay {
                                RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                            }
                    }
                } else {
                    mainView()
                }
            }
            
        }
        .navigationBarBackButtonHidden().navigationTitle("Edit File Name").onAppear(perform: loadImage)
    }
    
    private func mainView() -> some View {
            VStack(spacing: 15) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack {
                            HStack{
                                Text("Current File Name").font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)
                                Spacer()
                            }.padding(.top, 50).padding(.bottom, 10)
                            HStack{
                                Text(oldName).font(.system(size: 20, weight: .light, design: .serif)).padding(.leading, 16)
                                    .padding(.trailing, 16).lineLimit(nil).multilineTextAlignment(.leading)
                                Spacer()
                            }
                            Rectangle().frame(maxWidth:.infinity,minHeight: 1,maxHeight: 1)
                                                     .foregroundColor(.black).padding(.leading, 16)
                                                     .padding(.trailing, 16).padding(.bottom,50).id("BottomConstant")
                        }
                    }.onReceive(Just(isNameFocused), perform: { _ in
                        if isNameFocused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(0.3)) {
                                proxy.scrollTo("BottomConstant")
                            }
                            
                        }
                    })
                }
                GroupBox(label: Text("New File Name").font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)){
                    ScrollView {
                        VStack(spacing: 1) {
                            HStack{
                                TextField("Enter New Name", text: $newName, axis: .vertical).font(.system(size: 20, weight: .light, design: .serif)).padding(.leading, 16)
                                    .padding(.trailing, 16).lineLimit(nil).multilineTextAlignment(.leading).focused($isNameFocused).task {
                                        isNameFocused = true
                                    }
                                Spacer()
                            }
                            Rectangle().frame(maxWidth:.infinity,minHeight: 1,maxHeight: 1)
                                                     .foregroundColor(.black).padding(.leading, 16)
                                                     .padding(.trailing, 16).padding(.top, 10)
                            HStack {
                                Button {
                                    changeImageName()
                                } label: {
                                    Text("Save").font(.title2).foregroundColor(.white)
                                }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                    .overlay {
                                        RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                    }
                               
                                Button {
                                    navigationStateManager.selectionPath.removeLast()
                                } label: {
                                    Text("Cancel").font(.title2).foregroundColor(.white)
                                }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                    .overlay {
                                        RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                    }
                            }.padding(.top, 20)
                        }
                        
                    }.frame(height: 120)
                    
                }.backgroundStyle(.white)
                Spacer()
        }.onTapGesture {
                isNameFocused = false
            }
    }
    private func loadImage() {
        isProcessing.toggle()
        Task {
            do {
                let photoItem: ImageProperties = try await photoListPresenter.loadCurrentPhotoFromAlbum(albumId: folderId, albumName: folderName, photoId: pictureId)
                oldName = photoItem.name
                newName = photoItem.name
                isProcessing.toggle()
            } catch {
                isProcessing.toggle()
            }
        }
    }
    
    private func changeImageName() {
        isProcessing.toggle()
        if newName == oldName {
            isProcessing.toggle()
            savingError = NSError(domain: "EditPhoto", code: 2008, userInfo: [NSLocalizedDescriptionKey: "You choose the same name."])
            return
        }
        if newName.isEmpty {
            savingError = NSError(domain: "EditPhoto", code: 2008, userInfo: [NSLocalizedDescriptionKey: "Empty name."])
            isProcessing.toggle()
            return
        }
        Task{
            do {
                try await photoListPresenter.updatePhotoName(albumId: folderId, albumName: folderName, photoId: pictureId, newName: newName)
                isProcessing.toggle()
                navigationStateManager.selectionPath.removeLast()
            } catch {
                savingError = error
                isProcessing.toggle()
            }
        }
    }
}

struct ChangePictureNameView_Previews: PreviewProvider {
    static var previews: some View {
        ChangePictureNameView(photoListPresenter: PhotoListPresenter(), folderId: "Some", folderName: "Folder", pictureId: UUID())
    }
}
