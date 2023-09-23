//
//  CameraView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.06.2022.
//

import SwiftUI
import CoreImage

struct CameraView: View {
    var photoCreator = PhotoCreator()
    var photoListPresenter: PhotoListPresenter
    @StateObject var audioPlayerModel =  CameraSoundModel()
    @StateObject private var model = CameraViewModel()
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    @State private var isProcessing: Bool = false
    @State private var lastImage: Image?
    @State private var lastImageId: UUID?
    let albumId: String
    let folderName: String
    private let label = Text("Saving...").font(.title)
    @GestureState var magnifyBy = 1.0
    var magnification: some Gesture {
            MagnificationGesture()
                .updating($magnifyBy) { currentState, gestureState, transaction in
                    gestureState = currentState
                }.onChanged { (val: MagnificationGesture.Value)in
                    model.pinch(scale: val)
                }.onEnded { (lastvalue:GestureStateGesture<MagnificationGesture, Double>.Value) in
                             model.endPinch(scale: lastvalue)
                }
        }
    var body: some View {
        mainView().gesture(magnification).navigationBarHidden(true)
    }
    
    private func mainView() -> some View {
        ZStack {
          FrameView(image: model.frame)
                .edgesIgnoringSafeArea(.all)
          ErrorView(error: model.error)
           
            VStack {
                Spacer()
                HStack(alignment:.center, spacing: 10){
                    Spacer()
                    Button {
                        guard let lastId: UUID = lastImageId else {
                            return
                        }
                        navigationStateManager.selectionPath.append(.photoDetail(albumId, folderName, lastId))
                    } label: {
                        if let img:Image = lastImage {
                            img.resizable()
                        }
                    }.frame(width: 50, height: 50)
                        .cornerRadius(10)

                    Spacer()
                    Button(action: {
                        isProcessing.toggle()
                        Task {
                            do {
                                try await Task.sleep(nanoseconds: 500000000)
                                model.isCreate.toggle()
                            } catch {
                                model.error = error
                            }
                        }
                        
                    }, label: {
                        Image("CapturePhoto")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white)
                    }).disabled((isProcessing == true || audioPlayerModel.isPlayng == true) ? true : false).opacity((isProcessing == true || audioPlayerModel.isPlayng == true) ? 0.3 : 1.0)
                    .frame(width: 60, height: 60)
                    .cornerRadius(10)
                    Spacer()
                    Button {
                        
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill").resizable()
                            .renderingMode(.template)
                            .foregroundColor(.white).opacity(0.0)
                    }.frame(width: 50, height: 50)
                        .cornerRadius(10)
                    Spacer()
                }
            }
            VStack{
                HStack{
                    Spacer()
                    Button {
                        navigationStateManager.selectionPath.removeLast()
                    } label: {
                        Image(systemName: "multiply.circle.fill").resizable().renderingMode(.template).foregroundColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                       
                    }.frame(width: 50, height: 50)
                        .cornerRadius(10)
                }
                Spacer()
            }
            
        }.onChange(of: model.isCreate) { newValue in
            if newValue == false {
                if isProcessing {
                    createPhoto()
                }
            }
        }.onAppear{
            audioPlayerModel.prepareSoundClick()
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation") // Forcing the rotation to portrait
                        AppDelegate.orientationLock = .portrait // And making sure it stays that way
            loadItems()
        }.onDisappear{
            audioPlayerModel.stopPlayer()
            AppDelegate.orientationLock = .all 
        }
    }
    
    private func createPhoto() {
        guard let img: CIImage = model.photo else {
           isProcessing.toggle()
            return
        }
        Task {
            do {
                try await photoCreator.savePhoto(ciImage: img, albumId: albumId, albumName: folderName)
                audioPlayerModel.playSound()
                loadItems()
                isProcessing.toggle()
            } catch {
                isProcessing.toggle()
                model.error = error
            }
        }
    }
    
    private func loadItems() {
        isProcessing.toggle()
        Task {
            do {
                let photoProperties: [ImageProperties] = try  await photoListPresenter.loadPhotoFromAlbum(albumId: albumId, albumName: folderName)
                if let photo: ImageProperties = photoProperties.last {
                    lastImage = photo.image
                    lastImageId = photo.id
                } else {
                    lastImage = nil
                    lastImageId = nil
                }
                isProcessing.toggle()
            } catch {
                
                isProcessing.toggle()
               
            }
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    
    static var previews: some View {
        CameraView(photoListPresenter:PhotoListPresenter(),albumId: "Id", folderName: "Name")
    }
}
