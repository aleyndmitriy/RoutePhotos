//
//  ListGoogleDriveFoldersView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 06.10.2022.
//

import SwiftUI

struct ListGoogleDriveFoldersView: View {
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    @ObservedObject var remoteFolderEditObject: RemoteFolderEditObject
    @State private var isCreateFinished: Bool = false
    @State private var remoteFileName: String = String()
    @Binding var isSyncFinished: Bool
    @Binding var singleSelection: String?
    @Binding var newFileName: String?
    var body: some View {
        VStack {
            List(selection: $singleSelection) {
                Section {
                    ForEach(remoteFolderEditObject.oneDimensionalList) { item in
                        ChoseFolderRowView(remoteFolderEditObject: remoteFolderEditObject, selectedItem: $singleSelection, isSyncFinished: $isSyncFinished, isExpand:item.expanded,level: item.level, itemId: item.id ,text: item.folderDescription)
                    }
                } footer: {
                    HStack() {
                        Button {
                            if singleSelection != nil {
                                singleSelection = nil
                                remoteFolderEditObject.remoteFolderId = String()
                                remoteFolderEditObject.remoteFolderPath = String()
                                remoteFolderEditObject.remoteDriveId = String()
                            }
                        } label: {
                            Text("Deselect all").foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
            }.environment(\.editMode, .constant(.active)).listStyle(.plain).navigationTitle("Choose folder")
            HStack(spacing: 20) {
                Button {
                    if let select:String = singleSelection {
                        remoteFolderEditObject.remoteFolderId = select
                        let res = remoteFolderEditObject.createRemotePath(selected: select)
                        remoteFolderEditObject.remoteFolderPath = res.0
                        remoteFolderEditObject.remoteDriveId = res.1
                    }
                    navigationStateManager.selectionPath.removeLast()
                } label: {
                    Text("Select").font(.title2).foregroundColor(.white)
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
            }
        }.sheet(isPresented: $isCreateFinished,
                onDismiss: didDismiss){
            VStack {
                HStack {
                    Text("Create Remote Folder").font(.system(size: 18, weight: .semibold, design: .serif))
                }.frame(maxWidth:.infinity,maxHeight: 50).background(Color(red: 192.0/255.0, green: 239.0/255.0, blue: 239.0/255.0))
                Spacer()
                TextField("Enter Folder Name", text: $remoteFileName).font(.system(size: 20, weight: .light, design: .serif)).padding(.leading, 16)
                    .padding(.trailing, 16)
                Rectangle().frame(maxWidth:.infinity,minHeight: 1,maxHeight: 1)
                                         .foregroundColor(.black).padding(.leading, 16)
                                         .padding(.trailing, 16)
                Spacer()
                HStack {
                    Button {
                        isCreateFinished.toggle()
                        if remoteFileName.isEmpty == false {
                            isSyncFinished.toggle()
                            newFileName = remoteFileName
                        }
                    } label: {
                        Text("Create").font(.title2).foregroundColor(.white)
                    }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                        .overlay {
                            RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                        }
                   
                    Button {
                        isCreateFinished.toggle()
                    } label: {
                        Text("Cancel").font(.title2).foregroundColor(.white)
                    }.frame(width: 120,height: 45).background(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0)).clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                        .overlay {
                            RoundedRectangle(cornerSize: CGSize(width:20, height: 20)).stroke(.white, lineWidth: 3)
                        }

                }
            }.preferredColorScheme(.light)
        }.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                                    Button {
                                        isCreateFinished.toggle()
                                    } label: {
                                        Image(systemName: "folder.badge.plus").resizable().frame(width: 25, height: 20, alignment: .center).foregroundColor(.black)
                                    }
                                }
        }
    }
    private func didDismiss() {
        
    }
}

struct ListGoogleDriveFoldersView_Previews: PreviewProvider {
    static var previews: some View {
        ListGoogleDriveFoldersView( remoteFolderEditObject: RemoteFolderEditObject(), isSyncFinished: .constant(false),singleSelection: .constant(nil), newFileName: .constant(nil))
    }
}
