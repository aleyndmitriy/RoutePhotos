//
//  AddMessageView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 26.01.2023.
//

import SwiftUI
import Combine

struct AddMessageView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    var photoListPresenter: PhotoListPresenter
    let folderId: String
    let folderName: String
    let pictureId: UUID
    @State private var isProcessing: Bool = false
    @State private var loadingError: Error?
    @State private var messages = [MessageProperties]()
    @State private var pictureName = String()
    @State private var messageText = String()
    @FocusState var isTextFocused : Bool
    var body: some View {
        Grid{
            if isProcessing {
                ProgressView()
            } else {
                if let err: Error = loadingError {
                    VStack {
                        Spacer()
                        Text(err.localizedDescription).font(.title3)
                        Button {
                            loadingError = nil
                        } label: {
                            Text("Ok").font(.title2).foregroundColor(.white)
                        }.frame(width: 100,height: 40).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                            .overlay {
                                RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                            }.padding(.trailing, 16)
                        Spacer()
                    }
                } else {
                    VStack {
                        ScrollViewReader { proxy in
                            ScrollView(.vertical) {
                                LazyVStack {
                                    ForEach($messages) {
                                      message in MessageRowView(photoListPresenter: photoListPresenter, message: message)
                                    }
                                    Text("")         .id("BottomConstant")
                                }.onTapGesture {
                                    isTextFocused = false
                                }
                            }.onReceive(Just(messages), perform: { _ in
                                if messages.count > 0 {
                                    proxy.scrollTo("BottomConstant")
                                }
                            })
                       
                        }
                        Spacer()
                        GroupBox(label: Text("New message")) {
                            ScrollView {
                                TextField("Add Text", text: $messageText, axis: .vertical).focused($isTextFocused).padding()
                            }.frame(height: 100)
                            HStack{
                                Spacer()
                                Button {
                                    createMessage()
                                } label: {
                                    Text("Save").font(.title3).foregroundColor(.white)
                                }.frame(width: 80,height: 40).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                                    .overlay {
                                        RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                                    }.padding(.trailing, 16)

                            }
                        }
                    }
                    
                }
            }
        }.navigationTitle("Messages").onAppear {
            loadMessages()
        }
    }
    
    private func loadMessages() {
        Task {
            do {
                isProcessing.toggle()
                let imageProperty = try await photoListPresenter.loadCurrentPhotoFromAlbum(albumId: folderId, albumName: folderName, photoId: pictureId)
                pictureName = imageProperty.name
                messages = try await photoListPresenter.loadCurrentPhotoMessags(albumId: folderId, albumName: folderName, photoId: pictureId)
                isProcessing.toggle()
            } catch {
                    isProcessing.toggle()
                    loadingError = error
            }
        }
    }
    
    private func createMessage() {
        if messageText.isEmpty {
            return
        }
        Task {
            do {
                isProcessing.toggle()
                var messageName: String =  pictureName
                if messages.count > 0 {
                    messageName = "\(messages.count)_" + messageName
                }
                try await photoListPresenter.createMessage(albumId: folderId, albumName: folderName, photoId: pictureId, messageName: messageName, text: messageText)
                messages = try await photoListPresenter.loadCurrentPhotoMessags(albumId: folderId, albumName: folderName, photoId: pictureId)
                messageText = String()
                isProcessing.toggle()
            } catch {
                isProcessing.toggle()
                loadingError = error
            }
        }
    }
}

struct AddMessageView_Previews: PreviewProvider {
    static var previews: some View {
        AddMessageView(photoListPresenter: PhotoListPresenter(), folderId: "newId", folderName: "Name", pictureId: UUID())
    }
}
