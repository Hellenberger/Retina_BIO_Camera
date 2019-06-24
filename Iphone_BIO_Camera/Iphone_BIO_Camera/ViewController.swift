//  ViewController.swift
//  ReplicateCameraView
//
//  Created by Howard Ellenberger on 6/19/19.
//  Copyright © 2019 Howard Ellenberger. All rights reserved.

import UIKit
import CoreAudio
import MediaPlayer
import AVFoundation
import Photos
import AudioToolbox

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    @IBOutlet var mainView: UIView!
    
    @IBOutlet weak var cameraView: UIImageView!
    
    let viewBackgroundColor : UIColor = UIColor.black // UIColor.white
    var initialVolume: Float = 0.0
    var volumeView: MPVolumeView!
    var audioSession: AVAudioSession?
    var volumeUpdated: Bool = false
    
    var image: UIImage?
    var captureDevice: AVCaptureDevice?
    var session: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var photoSetting = AVCapturePhotoSettings()
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
//    var flashMode = AVCaptureDevice.FlashMode.off
    var photoOutput: AVCapturePhotoOutput?
    
    override var prefersStatusBarHidden: Bool { return true }
    
    @IBAction func buttonPressed(_ sender: Any?) {
        print("Button Pressed")
        
        print(initialVolume)
        MPVolumeView.setVolume(0.5)

        takePhoto ()

        captureImage {(newImage, error) in
            guard let image = newImage else {
                print(error ?? "Image capture error")
                return
            }
            let squareImage = image.cropToSquare(image: image)
            let roundedImage = squareImage?.roundedImage()
            let newImage = roundedImage?.rotate(radians: -.pi/2) // Rotate 90 degrees

            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAsset(from: newImage!)
            }
        }
    }
}

extension ViewController {
   
    func takePhoto() {
        MPVolumeView.setVolume(0.5)
        
        func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            
            guard error == nil else { print("Error capturing photo: \(error!)"); return }
            
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else { return }
                
                PHPhotoLibrary.shared().performChanges({
                    // Add the captured photo's file data as the main resource for the Photos asset.
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: photo.fileDataRepresentation()!, options: nil)
                })
            }
            
            if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
            
            guard let imageData = photo.fileDataRepresentation()
                else { return }
            let capturedImage = UIImage.init(data: imageData , scale: 1.0)
            let squareImage = capturedImage?.cropToSquare(image: image!)
            
            if let image = squareImage {
                self.photoCaptureCompletionBlock?(image, nil)
            }

            
            //MARK: - Save image
            func saveImage() {
                
                guard let selectedImage = cameraView.image
                    else {
                    return
                }
                
                UIImageWriteToSavedPhotosAlbum(selectedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    //MARK: - Save Image callback
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        
        if let error = error {
            
            print(error.localizedDescription)
            
        } else {
            
            print("Success")
        }
    }
    
    func flashActive() {
        if let currentDevice = AVCaptureDevice.default(for: AVMediaType.video), currentDevice.hasTorch {
            do {
                try currentDevice.lockForConfiguration()
                let torchOn = !currentDevice.isTorchActive
                currentDevice.torchMode = torchOn ? .on : .off
                currentDevice.unlockForConfiguration()
            } catch {
                print("error")
                
            }
            do {
                try currentDevice.lockForConfiguration()
                try currentDevice.setTorchModeOn(level: 0.1) } catch { currentDevice.unlockForConfiguration() }
        }
    }

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mainView.layer.cornerRadius = 170

        let cameraView = CALayer()
        let replicatorLayer = CAReplicatorLayer()
        let instanceCount = 2
        replicatorLayer.instanceCount = 2
        replicatorLayer.instanceCount = instanceCount
        replicatorLayer.frame = CGRect(x: 51, y: 75, width: 225, height: 225)
        replicatorLayer.instanceTransform = CATransform3DMakeTranslation(340, 0, 0)
        replicatorLayer.addSublayer(cameraView)
        self.view.layer.addSublayer(replicatorLayer)
        
        var settings = AVCapturePhotoSettings()

        startListeningVolumeButton()
        
        //Camera
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            if response {
                //access granted
            } else {
            }
        }
        
        session = AVCaptureSession()
        session!.sessionPreset = AVCaptureSession.Preset.high
        
        let backCamera =  AVCaptureDevice.default(for: AVMediaType.video)
        var error: NSError?
        var input: AVCaptureDeviceInput!
        
        do {
            input = try AVCaptureDeviceInput(device: backCamera!)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
        
        if error == nil && session!.canAddInput(input) {
            session!.addInput(input)
            photoOutput = AVCapturePhotoOutput()
            
            // Configure camera
            settings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.isAutoStillImageStabilizationEnabled = true

            if session!.canAddOutput(photoOutput!) {
                session!.addOutput(photoOutput!)
                
                self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session) as AVCaptureVideoPreviewLayer
                self.videoPreviewLayer?.frame.size = self.cameraView.frame.size
                self.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                self.videoPreviewLayer?.connection?.videoOrientation = .landscapeRight
                self.videoPreviewLayer.frame = cameraView.frame
                cameraView.addSublayer(videoPreviewLayer)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        session.startRunning()
        flashActive()
        print("viewwillappear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.videoPreviewLayer?.frame.size = self.cameraView.frame.size
    }
    
    enum CameraViewControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = session, captureSession.isRunning else { completion(nil, CameraViewControllerError.captureSessionIsMissing); return }
        
        let settings = AVCapturePhotoSettings()
//        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
}

public extension UIImage {
    func cropToSquare(image: UIImage) -> UIImage? {
        var imageHeight = image.size.height
        var imageWidth = image.size.width
        
        if imageHeight > imageWidth {
            imageHeight = imageWidth
        }
        else {
            imageWidth = imageHeight
        }
        
        let size = CGSize(width: imageWidth, height: imageHeight)
        
        let refWidth : CGFloat = CGFloat(image.cgImage!.width)
        let refHeight : CGFloat = CGFloat(image.cgImage!.height)
        
        let x = (refWidth - size.width) / 2
        let y = (refHeight - size.height) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size.height, height: size.width)
        if let imageRef = image.cgImage!.cropping(to: cropRect) {
            let cropToSquare : UIImage = UIImage(cgImage: imageRef, scale: 0, orientation: image.imageOrientation)
            
            return cropToSquare
        }
        
        return nil
    }
    
    func roundedImage() -> UIImage {
        let imageView: UIImageView = UIImageView(image: self)
        let layer = imageView.layer
        layer.masksToBounds = true
        layer.cornerRadius = imageView.frame.width / 2
        UIGraphicsBeginImageContext(imageView.bounds.size)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return roundedImage!
    }
}

extension ViewController {
   
   public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
        
        guard let imageData = photo.fileDataRepresentation() else { return }

    if let image = UIImage(data: imageData) {

            self.photoCaptureCompletionBlock?(image, nil)
            }
            
        else {
            self.photoCaptureCompletionBlock?(nil, CameraViewControllerError.unknown)
        }
    }
}

extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }

}

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        // Need to use the MPVolumeView in order to change volume, but don't care about UI set so frame to .zero
        let volumeView = MPVolumeView(frame: .zero)
        // Search for the slider
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        // Update the slider value with the desired volume.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = volume
        }
        // Optional - Remove the HUD
        if let app = UIApplication.shared.delegate as? AppDelegate, let window = app.window {
            volumeView.alpha = 0.000001
            window.addSubview(volumeView)
        }
    }
}

extension ViewController {
    
    static func setVolume(_ volume: Float) {
        // Need to use the MPVolumeView in order to change volume, but don't care about UI set so frame to .zero
        let volumeView = MPVolumeView(frame: .zero)
        // Search for the slider
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        // Update the slider value with the desired volume.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = volume
        }
        // Optional - Remove the HUD
        if let app = UIApplication.shared.delegate as? AppDelegate, let window = app.window {
            volumeView.alpha = 0.000001
            window.addSubview(volumeView)
        }
    }
    
    func startListeningVolumeButton() {
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            
            let vol = audioSession.outputVolume
            initialVolume = Float(vol.description)!
            if initialVolume > 0.6 {
                initialVolume = 0.5
            } else if initialVolume < 0.4 {
                initialVolume = 0.5
            }
            
            audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
        } catch {
            print("Could not observe outputVolume ", error)
        }
    }
    
    func stopListeningVolumeButton() {
        
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        
        volumeView.removeFromSuperview()
        volumeView = nil
    }
    
    func setVolume(_ volume: Float) {
        (volumeView.subviews.filter{NSStringFromClass($0.classForCoder) == "MPVolumeSlider"}.first as? UISlider)?.setValue(initialVolume, animated: false)
    }
    //
    //    func volumeUp() {
    //        buttonPressed(Any?.self)
    //        print("volume up")
    //    }
    //
    //    func volumeDown() {
    //        buttonPressed(Any?.self)
    //        print("volume down")
    //    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            buttonPressed(Any?.self)
            AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
            AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}


