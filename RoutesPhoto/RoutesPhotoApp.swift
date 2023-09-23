//
//  RoutesPhotoApp.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 19.06.2022.
//

import SwiftUI
import FirebaseCore
import BackgroundTasks
import SwiftyDropbox
import MSAL

func scheduleAppUploading() {
    let request = BGProcessingTaskRequest(identifier: "com.LineSoftwareRoutesPhoto.uploadingTask")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60) // Fetch no earlier than 2 minutes from now
    request.requiresNetworkConnectivity = true
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Could not schedule app refresh: \(error)")
    }
}

func uploadingProcess() async {
    await withThrowingTaskGroup(of: Void.self, body:{ taskGroup in
         taskGroup.addTask {
             try await PhotosOneDriveSender.shared.backgroundSynchronization()
         }
        taskGroup.addTask {
           try await PhotosGoogleDropBoxSender.shared.backgroundSynchronization()
        }
        taskGroup.addTask {
            try await PhotosGoogleDriveSender.shared.backgroundSynchronization()
        }
     })
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
      DropboxClientsManager.setupWithAppKey(GoogleDropBoxService.appKey)
     let isRegistered = BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.LineSoftwareRoutesPhoto.uploadingTask", using: nil) { task in
          if let processingTask: BGProcessingTask = task as? BGProcessingTask {
              self.handleAppUploading(task: processingTask)
          }
      }
    return true
  }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String) == true {
            print("This URL is handled by MSAL")
        }
        return true
    }
        func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            return AppDelegate.orientationLock
        }
    
    func handleAppUploading(task: BGProcessingTask) {
        task.expirationHandler = {
            PhotosGoogleDriveSender.shared.isCancel = true
            PhotosGoogleDropBoxSender.shared.isCancel = true
            PhotosOneDriveSender.shared.isCancel = true
            
        }
        Task {
            PhotosGoogleDriveSender.shared.isCancel = false
            PhotosGoogleDropBoxSender.shared.isCancel = false
            PhotosOneDriveSender.shared.isCancel = false
            await uploadingProcess()
            task.setTaskCompleted(success: true)
            scheduleAppUploading()
        }
    }
}

@main
struct RoutesPhotoApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject var networkMonitor: NetworkMonitor = NetworkMonitor.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
                ContentView().environmentObject(networkMonitor)
        }.onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Synchronizer.shared.resume()
                print("Active")
            } else if newPhase == .inactive {
                print("Inactive")
            } else if newPhase == .background {
                Synchronizer.shared.suspend()
                scheduleAppUploading()
                Task {
                    await uploadingProcess()
                    print("Background")
                }
            }
        }
    }
}
