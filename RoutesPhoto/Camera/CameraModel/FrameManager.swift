//
//  FrameManager.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.06.2022.
//

import AVFoundation

class FrameManager: NSObject, ObservableObject {
  var cameraManager: CameraManager
  @Published var current: CMSampleBuffer?

  let videoOutputQueue = DispatchQueue(
    label: "com.frameManager.VideoOutputQ",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem)

   init(cameraManager: CameraManager) {
       self.cameraManager = cameraManager
       super.init()
       self.cameraManager.set(self, queue: videoOutputQueue)
  }
}

extension FrameManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
      DispatchQueue.main.async {
        self.current = sampleBuffer
      }
    
  }
}
