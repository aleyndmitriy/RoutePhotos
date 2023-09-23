//
//  CameraManager.swift
//  RoutesPhoto
//
//  Created by Dmitrij Aleinikov on 21.06.2022.
//

import AVFoundation

class CameraManager: ObservableObject {
  enum Status {
    case unconfigured
    case configured
    case unauthorized
    case failed
  }
    //static let shared = CameraManager()

    @Published var error: CameraError?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.cameraManager.SessionQ")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var status = Status.unconfigured
    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 7.0
    var lastZoomFactor: CGFloat = 1.0
    var device: AVCaptureDevice?
    
    init() {
      configure()
    }

    deinit {
        sessionQueue.async {
          self.session.stopRunning()
        }
    }
    
    private func set(error: CameraError?) {
      DispatchQueue.main.async {
        self.error = error
      }
    }
    
    private func checkPermissions() {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .notDetermined:
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { authorized in
          if !authorized {
            self.status = .unauthorized
            self.set(error: .deniedAuthorization)
          }
          self.sessionQueue.resume()
        }
      case .restricted:
        status = .unauthorized
        set(error: .restrictedAuthorization)
      case .denied:
        status = .unauthorized
        set(error: .deniedAuthorization)
      case .authorized:
        break
      @unknown default:
        status = .unauthorized
        set(error: .unknownAuthorization)
      }
    }
    
    private func configureCaptureSession() {
      guard status == .unconfigured else {
        return
      }

      session.beginConfiguration()

      defer {
        session.commitConfiguration()
      }

      device = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: .back)
      guard let camera = device else {
        set(error: .cameraUnavailable)
        status = .failed
        return
      }

      do {
        let cameraInput = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(cameraInput) {
          session.addInput(cameraInput)
        } else {
          set(error: .cannotAddInput)
          status = .failed
          return
        }
      } catch {
        set(error: .createCaptureInput(error))
        status = .failed
        return
      }

      if session.canAddOutput(videoOutput) {
        session.addOutput(videoOutput)

        videoOutput.videoSettings =
          [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
      } else {
        set(error: .cannotAddOutput)
        status = .failed
        return
      }

      status = .configured
    }

    private func configure() {
      checkPermissions()

      sessionQueue.async {
        self.configureCaptureSession()
        self.session.startRunning()
      }
    }

    func pinch(scaleFactor: CGFloat) {
        let newScaleFactor = minMaxZoom(scaleFactor * lastZoomFactor)
        self.update(scale: newScaleFactor)
    }
    
    
    func endPinch(scaleFactor: CGFloat) {
        let newScaleFactor = minMaxZoom(scaleFactor * lastZoomFactor)
        lastZoomFactor = minMaxZoom(newScaleFactor)
        update(scale: lastZoomFactor)
    }
    private func minMaxZoom(_ factor: CGFloat) -> CGFloat {
        guard let camera = device else {
          return minimumZoom
        }
        return min(min(max(factor, minimumZoom), maximumZoom), camera.activeFormat.videoMaxZoomFactor)
    }
        
    private func update(scale factor: CGFloat) {
        guard let camera = device else {
          return
        }
        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            camera.videoZoomFactor = factor
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    func set(
      _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
      queue: DispatchQueue
    ) {
      sessionQueue.async {
        self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
      }
    }
}
