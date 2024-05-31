import Foundation
import AVFoundation
import Photos
import UIKit

class CameraService {
    
    var session: AVCaptureSession?
    var delegate: AVCapturePhotoCaptureDelegate?
    
    let output = AVCapturePhotoOutput()
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    func start(delegate: AVCapturePhotoCaptureDelegate, completion: @escaping (Error?) -> ()) {
        self.delegate = delegate
        checkPermissions(completion: completion)
    }
    
    private func checkPermissions(completion: @escaping (Error?) -> ()) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.setupCamera(completion: completion)
                }
            }
        case .restricted, .denied:
            // Handle the case where access is restricted or denied
            let error = NSError(domain: "CameraService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Camera access is restricted or denied"])
            completion(error)
        case .authorized:
            setupCamera(completion: completion)
        @unknown default:
            break
        }
    }
    
    private func setupCamera(completion: @escaping (Error?) -> ()) {
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    completion(NSError(domain: "CameraService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to add input"]))
                    return
                }
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                } else {
                    completion(NSError(domain: "CameraService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to add output"]))
                    return
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                session.startRunning()
                self.session = session
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    func capturePhoto(with settings: AVCapturePhotoSettings = AVCapturePhotoSettings()) {
        guard let connection = output.connection(with: .video), connection.isActive, connection.isEnabled else {
            print("No active and enabled video connection")
            return
        }
        output.capturePhoto(with: settings, delegate: delegate!)
    }
}
