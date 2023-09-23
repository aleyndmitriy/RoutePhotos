//
//  SettingsView.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 28.09.2022.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var internetMonitor: NetworkMonitor
    @EnvironmentObject var navigationStateManager: NavigationStateManager
    let uploadSettings = UserDefaultUploadingSettings()
    @State private var uploadCellular: Bool = true
    @State private var uploadWiFi: Bool = true
    @State private var syncInterval = 120.0
    @State private var isEditing = false
    var body: some View {
        VStack(spacing: 15) {
            VStack(spacing: 15) {
                Toggle("Upload on Cellular", isOn: $uploadCellular).tint(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                Toggle("Upload on WiFi", isOn: $uploadWiFi).tint(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                Slider(value: $syncInterval,
                            in: 120...600,
                       step: 5){
                    Text("Uploading Interval")
                } minimumValueLabel: {
                    Text("120")
                } maximumValueLabel: {
                    Text("600")
                }
                    onEditingChanged: { editing in
                                isEditing = editing
                    }.accentColor(Color(red: 49.0/255.0, green: 140.0/255.0, blue: 148.0/255.0))
                        
                        Text("Uploading interval **\(Int(syncInterval))**")
                    
            }
            .toggleStyle(.switch).padding(20)
            Spacer()
        }.onAppear{
            Synchronizer.shared.suspend()
            uploadCellular = uploadSettings.getIsUploadOnCellularInterfaceSetting()
            uploadWiFi = uploadSettings.getIsUploadOnWiFiInterfaceSetting()
            syncInterval = Double(uploadSettings.getUploadTimeIntervalSetting())
        }.onDisappear{
            uploadSettings.setIsUploadOnCellularInterfaceSetting(uploadCellular)
            uploadSettings.setIsUploadOnWiFiInterfaceSetting(uploadWiFi)
            uploadSettings.setUploadTimeIntervalSetting(Int(syncInterval))
            Synchronizer.shared.refreshRateSec = syncInterval
            Synchronizer.shared.resume()
        }.navigationTitle("Settings").toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                                    Button {
                                        navigationStateManager.selectionPath.append(.addFolder)
                                    } label: {
                                        Image(systemName: "folder.badge.plus").resizable().frame(width: 30, height: 25, alignment: .center).foregroundColor(.black)
                                    }
                                }
        }
    }
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
