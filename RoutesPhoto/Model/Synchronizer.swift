//
//  Synchronizer.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 28.09.2022.
//

import UIKit

private enum State {
    case suspended
    case resumed
    case internetWaited
}

class Synchronizer: NSObject {
    static let defaultTimeInterval: Int = 300
    static let shared = Synchronizer()
    private var timer: Timer?
    private var state: State = .suspended
    private var uploadingSettings = UserDefaultUploadingSettings()
    private let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
    private var syncError: Error?
    var refreshRateSec: TimeInterval = TimeInterval(300)
    private var synchronizing: Bool = false
    
    private override init() {
        super.init()
        self.center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                if granted {
                    print("Notifications are enabled!")
                } else {
                    print("Notifications are disabled!")
                }
            }
        NotificationCenter.default.addObserver(self, selector: #selector(resumeUploading(notification:)), name: Notification.Name(rawValue: "connectivityStatusChanged"), object: nil)
        NetworkMonitor.shared.startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    func resume() {
        if state == .resumed {
            NetworkMonitor.shared.stopMonitoring()
            timer?.invalidate()
        }
        state = .resumed
            self.timer = Timer.scheduledTimer(timeInterval: self.refreshRateSec, target: self, selector: #selector(self._sync), userInfo: nil, repeats: true)
        
    }
    
    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        NetworkMonitor.shared.stopMonitoring()
        timer?.invalidate()
    }
    
    func waitConnection(){
        if state == .internetWaited {
            return
        }
        state = .internetWaited
        timer?.invalidate()
    }
    
    public func Sync() {
        self._sync()
    }
    
    @objc private func _sync() {
        if self.synchronizing {
            return
        }
        guard NetworkMonitor.shared.isConnected else {
            waitConnection()
            return
        }
        if !uploadingSettings.getIsUploadOnCellularInterfaceSetting() && NetworkMonitor.shared.isExpensive {
            return
        }
        
        if !uploadingSettings.getIsUploadOnWiFiInterfaceSetting() && !uploadingSettings.getIsUploadOnCellularInterfaceSetting() {
            return
        }
        
        self.synchronizing = true
        self.syncError = nil
        
        Task {
            await withThrowingTaskGroup(of: Void.self, body:{ taskGroup in
                 taskGroup.addTask {
                     try await PhotosOneDriveSender.shared.synchronization()
                 }
                taskGroup.addTask {
                   try await PhotosGoogleDropBoxSender.shared.synchronization()
                }
                taskGroup.addTask {
                    try await PhotosGoogleDriveSender.shared.synchronization()
                }
             })
            self.synchronizing = false
        }
    }
    
    
    
    @objc func resumeUploading(notification: Notification) {
           if NetworkMonitor.shared.isConnected {
               if self.state == .internetWaited {
                   self.resume()
                   self._sync()
               }
               print("Connected")
           } else {
               print("Not connected")
           }
       }
}
