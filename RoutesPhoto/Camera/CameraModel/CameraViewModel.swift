//
//  CameraViewModel.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.06.2022.
//

import CoreImage
import CoreGraphics
import VideoToolbox
import Combine
import Firebase

class CameraViewModel: ObservableObject {
  @Published var error: Error?
  @Published var frame: CGImage?
  @Published var isCreate: Bool = false
  private let context = CIContext()
  private var sampleBuffer: CMSampleBuffer?
  private var imageBuffer: CVImageBuffer?
  private let cameraManager = CameraManager()
  private let frameManager: FrameManager
    
    var photo: CIImage?
  init() {
      self.frameManager = FrameManager(cameraManager: self.cameraManager)
      setupSubscriptions()
  }

    func pinch(scale: CGFloat) {
        cameraManager.pinch(scaleFactor: scale)
    }
    
    func endPinch(scale: CGFloat) {
        cameraManager.endPinch(scaleFactor: scale)
    }
    
  func setupSubscriptions() {
     cameraManager.$error
      .receive(on: DispatchQueue.main)
      .map { $0 }
      .assign(to: &$error)
      
    
      frameManager.$current
        .receive(on: DispatchQueue.main)
        .compactMap { buffer in
            guard let currentSampleBuffer: CMSampleBuffer = buffer, let imageBuff: CVImageBuffer = currentSampleBuffer.imageBuffer else {
            return nil
          }
            if self.isCreate {
                Crashlytics.crashlytics().setCustomValue("during creating photo" , forKey: "creation_key")
                Crashlytics.crashlytics().log("during creating photo")
                CMSampleBufferCreateCopy(allocator: nil, sampleBuffer: currentSampleBuffer, sampleBufferOut: &self.sampleBuffer)
                Crashlytics.crashlytics().setCustomValue("after creation image buffer" , forKey: "creation_key")
                Crashlytics.crashlytics().log("after creation image buffer")
                guard let sampleBuff: CMSampleBuffer = self.sampleBuffer, sampleBuff.isValid else {
                    Crashlytics.crashlytics().setCustomValue("error creation sample buffer" , forKey: "creation_key")
                    Crashlytics.crashlytics().log("error creation sample buffer")
                    self.isCreate.toggle()
                    return nil
                }
                self.imageBuffer = CMSampleBufferGetImageBuffer(sampleBuff)
                
                guard let imgBuff: CVImageBuffer = self.imageBuffer else {
                    Crashlytics.crashlytics().setCustomValue("error creation image buffer" , forKey: "creation_key")
                    Crashlytics.crashlytics().log("error creation image buffer")
                    return nil
                }
                self.photo = CIImage(cvImageBuffer: imgBuff)
                Crashlytics.crashlytics().log("creating CI photo")
                Crashlytics.crashlytics().setCustomValue("creation CI Photo" , forKey: "creation_key")
                self.isCreate.toggle()
                if let icPhoto: CIImage = self.photo {
                    Crashlytics.crashlytics().setCustomValue("before creating CI photo during savin" , forKey: "creation_key")
                    Crashlytics.crashlytics().log("before creating CI photo during saving")
                    return self.context.createCGImage(CIImage(color: .white), from: CGRect(x: 0, y: 0, width: icPhoto.extent.width, height: icPhoto.extent.height))
                }
            }
            Crashlytics.crashlytics().setCustomValue("before creating CI photo" , forKey: "creation_key")
            Crashlytics.crashlytics().log("before creating CI photo")
            let icPhoto: CIImage = CIImage(cvImageBuffer: imageBuff).transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            return self.context.createCGImage(icPhoto, from: icPhoto.extent)
        }
        .assign(to: &$frame)
  }
    
    func create(from cvPixelBuffer: CVPixelBuffer) -> CGImage? {
        
        var image: CGImage?
        let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow: Int = CVPixelBufferGetBytesPerRow(cvPixelBuffer)
        let height: Int = CVPixelBufferGetHeight(cvPixelBuffer)
        let width: Int = CVPixelBufferGetWidth(cvPixelBuffer)
        //let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        CVPixelBufferLockBaseAddress(cvPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let pixelData = CVPixelBufferGetBaseAddress(cvPixelBuffer), let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        image = context.makeImage()
        CVPixelBufferUnlockBaseAddress(cvPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return image
    }
}

func createCGImage(from cvPixelBuffer: CVPixelBuffer) -> CGImage? {

    var image: CGImage?
    VTCreateCGImageFromCVPixelBuffer(
        cvPixelBuffer,
      options: nil,
      imageOut: &image)
    return image
}
