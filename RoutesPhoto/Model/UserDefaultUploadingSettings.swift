//
//  UserDefaultUploadingSettings.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 28.09.2022.
//

import UIKit

class UserDefaultUploadingSettings: NSObject {
    private let uploadOnCellularInterfaceKey: String = "userUploadingOptions.IsUploadOnCellular"
    private let uploadOnWiFiInterfaceKey: String = "userUploadingOptions.IsUploadOnWiFi"
    private let uploadTimeIntervalKey: String = "userUploadingOptions.UploadTimeInterval"
    
    func getIsUploadOnCellularInterfaceSetting() -> Bool {
        if UserDefaults.standard.object(forKey: uploadOnCellularInterfaceKey) != nil {
            return UserDefaults.standard.bool(forKey: uploadOnCellularInterfaceKey)
        } else {
            return true
        }
    }
    
    func setIsUploadOnCellularInterfaceSetting(_ isInclude: Bool) {
        UserDefaults.standard.set(isInclude, forKey: uploadOnCellularInterfaceKey)
    }
    
    func getIsUploadOnWiFiInterfaceSetting() -> Bool {
        if UserDefaults.standard.object(forKey: uploadOnWiFiInterfaceKey) != nil {
            return UserDefaults.standard.bool(forKey: uploadOnWiFiInterfaceKey)
        } else {
            return true
        }
    }
    
    func setIsUploadOnWiFiInterfaceSetting(_ isInclude: Bool) {
        UserDefaults.standard.set(isInclude, forKey: uploadOnWiFiInterfaceKey)
    }
    
    func getUploadTimeIntervalSetting() -> Int {
        if UserDefaults.standard.object(forKey: uploadTimeIntervalKey) != nil {
            return UserDefaults.standard.integer(forKey: uploadTimeIntervalKey)
        } else {
            return Synchronizer.defaultTimeInterval
        }
    }
    
    func setUploadTimeIntervalSetting(_ interval: Int) {
        UserDefaults.standard.set(interval,forKey: uploadTimeIntervalKey)
    }
}
