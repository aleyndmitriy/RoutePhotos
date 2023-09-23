//
//  NetworkMonitor.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 28.09.2022.
//

import UIKit
import Network

final class NetworkMonitor: NSObject, ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkConnectivityMonitor")
    @Published var isConnected = false
    private(set) var isExpensive = true
    private(set) var currentConnectionType: NWInterface.InterfaceType = .loopback
    
    private override init() {
        self.monitor = NWPathMonitor()
        super.init()
    }
    
    deinit {
        self.monitor.cancel()
    }
    
    func startMonitoring() {
        self.monitor.pathUpdateHandler = { [weak self] newPath  in
            self?.isExpensive = newPath.isExpensive
            DispatchQueue.main.async {
                self?.isConnected = (newPath.status != .unsatisfied)
            }
            var connectionType : NWInterface.InterfaceType = .loopback
            if newPath.usesInterfaceType(NWInterface.InterfaceType.other) {
                connectionType = .other
                self?.currentConnectionType = NWInterface.InterfaceType.other
            } else if newPath.usesInterfaceType(NWInterface.InterfaceType.loopback) {
                connectionType = .loopback
                self?.currentConnectionType = NWInterface.InterfaceType.loopback
            }  else if newPath.usesInterfaceType(NWInterface.InterfaceType.cellular) {
                connectionType = .cellular
                self?.currentConnectionType = .cellular
            } else if newPath.usesInterfaceType(NWInterface.InterfaceType.wifi) {
                connectionType = .wifi
                self?.currentConnectionType = .wifi
            } else if newPath.usesInterfaceType(NWInterface.InterfaceType.wiredEthernet) {
                connectionType = .wiredEthernet
                self?.currentConnectionType = .wiredEthernet
            }
            var userInfo = [String: Any]()
            userInfo.updateValue(newPath.status, forKey: "ConnectionStatus")
            userInfo.updateValue(connectionType, forKey: "ConnectionType")
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "connectivityStatusChanged"),object: nil, userInfo: userInfo))
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        
    }
    
}
