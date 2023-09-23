//
//  PermissionsModel.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 31.10.2022.
//

import UIKit
import AVFoundation
import PhotosUI

class PermissionsModel: NSObject {

    override init() {
        AVCaptureDevice.requestAccess(for: .video) { (granted: Bool) in
            if granted {
                print("Camera is enabled!")
            } else {
                print("Camera is disabled!")
            }
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { (status: PHAuthorizationStatus) in
            switch status {
            case .authorized:
                print("Photos Library is enabled!")
                break
            case .denied:
                print("Photos Library is denided!")
                break
            default:
                break
            }
        }
    }
}
