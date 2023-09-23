//
//  AddCommentView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 31.01.2023.
//

import SwiftUI
import Combine

struct AddCommentView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    var photoListPresenter: PhotoListPresenter
    let folderId: String
    let folderName: String
    let pictureId: UUID
    @State private var isProcessing: Bool = false
    @State private var loadingError: Error?
    @State private var message: MessageProperties? 
    @State private var pictureName = String()
    @State private var messageText = String()
    @FocusState var isTextFocused: Bool
    var body: some View {
        Grid {
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
                    mainView()
                }
            }
        }.navigationTitle("Comment").onAppear {
            loadMessages()
        }
    }
    private func mainView() -> some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack {
                        HStack{
                            Text(pictureName).font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)
                            Spacer()
                        }.padding(.top, 50).padding(.bottom, 10)
                        if let mes = message {
                            HStack{
                                Text(mes.date, formatter: dateFotmatter()).font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)
                                Spacer()
                                messageStatus(mes.status).padding(.trailing,5)
                            }
                        }
                        Text("")         .id("BottomConstant")
                    }
                }.onReceive(Just(isTextFocused), perform: { _ in
                    if isTextFocused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(0.3)) {
                            proxy.scrollTo("BottomConstant")
                        }
                        
                    }
                })
            }
            GroupBox(label: Text("Comment text").font(.system(size: 16, weight: .light, design: .serif)).padding(.leading, 16)){
                ScrollView {
                    VStack(spacing: 20) {
                        HStack{
                            TextField("Enter Text", text: $messageText, axis: .vertical).font(.system(size: 20, weight: .light, design: .serif)).padding(.leading, 16)
                                .padding(.trailing, 16).lineLimit(nil).multilineTextAlignment(.leading).focused($isTextFocused).task {
                                    isTextFocused = true
                                }
                            Spacer()
                        }
                        Button {
                            createMessage()
                        } label: {
                            Text("Save").font(.title2).foregroundColor(.white)
                        }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                            .overlay {
                                RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                            }
                    }
                }.frame(height: 120)
                
                
            }.backgroundStyle(.white)
            Spacer()
        }.onTapGesture {
            isTextFocused = false
        }
    }
    private func loadMessages() {
        Task {
            do {
                isProcessing.toggle()
                let imageProperty = try await photoListPresenter.loadCurrentPhotoFromAlbum(albumId: folderId, albumName: folderName, photoId: pictureId)
                pictureName = imageProperty.name
                let messages = try await photoListPresenter.loadCurrentPhotoMessags(albumId: folderId, albumName: folderName, photoId: pictureId)
                message = messages.first
                if let mes = message {
                    messageText = mes.text
                }
                isProcessing.toggle()
            } catch {
                    isProcessing.toggle()
                    loadingError = error
            }
        }
    }
    private func messageStatus(_ status: PhotoStatus) -> some View {
        HStack {
            switch status {
            case .local:
                Image("iredcircle").resizable().frame(width: 15,height: 15,alignment: .center)
            case .pending:
                Image("iwhitecircle").resizable().frame(width: 15,height: 15,alignment: .center)
            case .synchronized:
                Image("igreencircle").resizable().frame(width: 15,height: 15,alignment: .center)
            }
        }
    }
    private func createMessage() {
        if messageText.isEmpty  {
            return
        }
        Task {
            do {
                isProcessing.toggle()
                let messageName: String =  pictureName
                if let mes = message {
                    let newMessage: MessageProperties = MessageProperties(id: mes.id, photoId: mes.photoId, name: messageName, text: messageText, date: Date(), status: .local)
                    try await photoListPresenter.updateMessage(albumId: folderId, albumName: folderName, message: newMessage)
                } else {
                    try await photoListPresenter.createMessage(albumId: folderId, albumName: folderName, photoId: pictureId, messageName: messageName, text: messageText)
                }
                let messages = try await photoListPresenter.loadCurrentPhotoMessags(albumId: folderId, albumName: folderName, photoId: pictureId)
                message = messages.first
                if let mes = message {
                    messageText = mes.text
                }
                isProcessing.toggle()
                navigationStateManager.selectionPath.removeLast()
            } catch {
                isProcessing.toggle()
                loadingError = error
            }
        }
    }
}

struct AddCommentView_Previews: PreviewProvider {
    static var previews: some View {
        AddCommentView(photoListPresenter: PhotoListPresenter(), folderId: "newId", folderName: "Name", pictureId: UUID())
    }
}
