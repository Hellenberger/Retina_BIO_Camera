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

    var timestamp:Double!
    let defaults = UserDefaults.standard
    let key = "PictureTaken"
    var button: UIButton!
    var label:UILabel!
    
    var audioPlayer = AVAudioPlayer()
    
    @IBOutlet weak var timeStamp: UILabel!
    
    @IBOutlet weak var imageSaved: UILabel!
    
    @IBOutlet weak var torchSlider: UISlider!
 
    @IBOutlet weak var sliderValue: UILabel!
    
    @IBOutlet var mainView: UIView!
    
    @IBOutlet weak var cameraView: UIImageView!
    
    @IBOutlet weak var lensPositionSlider: UISlider!
    
    @IBOutlet weak var lensPositionbValueLabel: UILabel!
    
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
    var photoOutput: AVCapturePhotoOutput?
    
    private var focusModes: [AVCaptureDevice.FocusMode] = []
    
    override var prefersStatusBarHidden: Bool { return true }
    
    @IBAction func lensSliderValueChanged(_ slider: UISlider) {
        
        let device = AVCaptureDevice.default(for: .video)
        do {
            try device?.lockForConfiguration()
        } catch {
        }
        do {
            try device?.setFocusModeLocked(lensPosition: slider.value)
        } catch {
        }
       
        self.lensPositionSlider.minimumValue = 0.0
        self.lensPositionSlider.maximumValue = 1.0
        let currentValue = slider.value
        let intValue = Int(currentValue * 100.0)
        let roundedValue = Double(intValue) / 100.0
        lensPositionbValueLabel.text = "\(roundedValue)"
        device?.unlockForConfiguration()
    }

    @IBAction func buttonPressed(_ sender: Any?) {
        print("Button Pressed")
        
        print(initialVolume)
        setVolumeLevel(initialVolume)
        
        takePhoto ()

        captureImage {(newImage, error) in
            guard let image = newImage else {
                print(error ?? "Image capture error")
                return
            }
            let flippedImage = image.withHorizontallyFlippedOrientation()
            

            let squareImage = flippedImage.cropToSquare(image: flippedImage)
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
        self.imageSaved.fadeOut(completion: {
            (finished: Bool) -> Void in
            self.imageSaved.text = "Image Saved"
            self.imageSaved.fadeIn()
            self.imageSaved.fadeOut()
        })
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
    
    private func findCamera() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInTelephotoCamera
        ]
        
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes,
                                                         mediaType: .video,
                                                         position: .back)
        
        return discovery.devices.first
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startListeningVolumeButton(initialVolume)
        setVolumeLevel(initialVolume)
        
        mainView.layer.cornerRadius = 120

        let cameraView = CALayer()
        let replicatorLayer = CAReplicatorLayer()
        let instanceCount = 2
        replicatorLayer.instanceCount = 2
        replicatorLayer.instanceCount = instanceCount
        replicatorLayer.frame = CGRect(x: 51, y: 75, width: 225, height: 225)
        replicatorLayer.instanceTransform = CATransform3DMakeTranslation(340, 0, 0)
        replicatorLayer.addSublayer(cameraView)
        self.view.layer.addSublayer(replicatorLayer)
        
        var settings = AVCapturePhotoBracketSettings()

        //Camera
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            if response {
                //access granted
            } else {
            }
        }
        
        session = AVCaptureSession()
        session!.sessionPreset = AVCaptureSession.Preset.high
                
        guard let backCamera = findCamera() else {
            print("No camera found")
            return
        }
        
        var error: NSError?

            do {
                // add the input
                let input = try AVCaptureDeviceInput(device: backCamera)
                if error == nil && session!.canAddInput(input) {
                    session!.addInput(input)
                    photoOutput = AVCapturePhotoOutput()
                    }
                } catch let error1 as NSError {
                    error = error1
                    print(error!.localizedDescription)
                }
        
            // Configure camera
        // Get AVCaptureBracketedStillImageSettings for a set of exposure values.
        let exposureValues: [Float] = [-2, 0, +2]
        let makeAutoExposureSettings = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias:)
        let exposureSettings = exposureValues.map(makeAutoExposureSettings)

        
        settings = AVCapturePhotoBracketSettings(rawPixelFormatType: 0,
                                                 processedFormat: [AVVideoCodecKey : AVVideoCodecType.hevc],
                                                 bracketedSettings: exposureSettings)
        settings.isLensStabilizationEnabled =
            self.photoOutput!.isLensStabilizationDuringBracketedCaptureSupported

                //.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
           // settings.isAutoStillImageStabilizationEnabled = true
            settings.isHighResolutionPhotoEnabled = true
            settings.isDualCameraDualPhotoDeliveryEnabled = true
            settings.isAutoDualCameraFusionEnabled = false
        // Shoot the bracket, using a custom class to handle capture delegate callbacks.
//        let captureProcessor = PhotoCaptureProcessor()
//        self.photoOutput.capturePhoto(with: settings, delegate: captureProcessor)

            if session!.canAddOutput(photoOutput!) {
                session!.addOutput(photoOutput!)
                
                self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session) as AVCaptureVideoPreviewLayer
                self.videoPreviewLayer?.frame.size = self.cameraView.frame.size
                self.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                self.videoPreviewLayer?.connection?.videoOrientation = .landscapeRight
                self.videoPreviewLayer.frame = cameraView.frame
                cameraView.addSublayer(videoPreviewLayer)
                
                do {
                    try backCamera.lockForConfiguration()
                    let zoomFactor:CGFloat = 2
                    backCamera.videoZoomFactor = zoomFactor
                    //backCamera.unlockForConfiguration()
                    try backCamera.lockForConfiguration()
                    backCamera.focusMode = .autoFocus
                    backCamera.unlockForConfiguration()
                } catch {
                    //Catch error from lockForConfiguration
                }
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider!) {
        
        let device = AVCaptureDevice.default(for: .video)
        do {
            try device?.lockForConfiguration()
        } catch {
        }
        do {
            try device?.setTorchModeOn(level: sender.value)
        } catch {
        }
        device?.unlockForConfiguration()
        
        torchSlider.maximumValue = 1.0
        torchSlider.minimumValue = 0.10
        
        let currentValue = sender.value
        let intValue = Int(currentValue * 100.0)
        let roundedValue = Double(intValue) / 100.0
        sliderValue.text = "\(roundedValue)"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        session.startRunning()
        timeAsText()
        flashActive()
    }
    
    func timeAsText() {
        let dateformatter = DateFormatter()

        dateformatter.dateStyle = DateFormatter.Style.long

        dateformatter.timeStyle = DateFormatter.Style.medium

        let now = dateformatter.string(from: Date())

        print("The Time is: ", now)
        timeStamp.text = now
        }
//    func dateInImage() {
//        if let context = UIGraphicsGetCurrentContext() {
//            cameraView.layer.render(in: context)
//        }
//        if let context = UIGraphicsGetCurrentContext() {
//            timeStamp.layer.render(in: context)
//        }
//        let textInImage = UIGraphicsGetImageFromCurrentImageContext()
//
//    }
    
//    func textToImage(drawText text: NSString, inImage image: UIImage) -> UIImage
//    {
//
//        UIGraphicsBeginImageContext(image.size)
//        image.draw(in: CGRect(x: 0, y: 0, width: (image.size.width), height: image.size.height))
//
//        let font=UIFont(name: "Helvetica-Bold", size: 8)!
//
//        let paraStyle=NSMutableParagraphStyle()
//        paraStyle.alignment=NSTextAlignment.center
//
//        let attributes = [NSAttributedString.Key.foregroundColor:UIColor.red, NSAttributedString.Key.font:font, NSAttributedString.Key.paragraphStyle:paraStyle]
//
//        let height = font.lineHeight
//
//        let y = (image.size.height-height) / 2
//
//        let strRect = CGRect(x: 0, y: y, width: image.size.width, height: height)
//
//        timeStamp.text?.draw(in: strRect.integral, withAttributes: attributes)
//
//        let result=UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//
//        let labelledImage = self.textToImage(drawText: timeStamp?.text! as! NSString, inImage: UIImage.init(named: image)!)
//        timeStamp.setBackgroundImage(image, for: UILabel)
//
//        return result!
//    }
    
    
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
        
        let exposureValues: [Float] = [-2, 0, +2]
        let makeAutoExposureSettings = AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias:)
        let exposureSettings = exposureValues.map(makeAutoExposureSettings)
        let settings = AVCapturePhotoBracketSettings(rawPixelFormatType: 0,
                                                     processedFormat: [AVVideoCodecKey : AVVideoCodecType.hevc],
                                                     bracketedSettings: exposureSettings)
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        
        
        
        self.photoCaptureCompletionBlock = completion
    }
}

extension UIView {
    func fadeIn(_ duration: TimeInterval = 0.0, delay: TimeInterval = 0.0, completion: @escaping ((Bool) -> Void) = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.alpha = 1.0
            }, completion: completion)  }

    func fadeOut(_ duration: TimeInterval = 2.0, delay: TimeInterval = 0.0, completion: @escaping (Bool) -> Void = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.alpha = 0.0
            }, completion: completion)
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
        let cameraView: UIImageView = UIImageView(image: self)
        let layer = cameraView.layer
        layer.masksToBounds = true
        layer.cornerRadius = cameraView.frame.width / 2
        UIGraphicsBeginImageContext(cameraView.bounds.size)
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
//        func generateImageWithText(text: String) -> UIImage
//            {
//
//            UIGraphicsBeginImageContextWithOptions(timeStamp.bounds.size, false, 0);
//            cameraView.layer.render(in: UIGraphicsGetCurrentContext()!)
//            timeStamp.layer.render(in: UIGraphicsGetCurrentContext()!)
//            let imageWithText = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext();
//
//            return imageWithText!
//            }
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

extension ViewController {

    func startListeningVolumeButton(_ volume: Float) {

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(true)

            let vol = audioSession.outputVolume
            initialVolume = Float(vol.description)!
            if initialVolume > 0.6 {
                initialVolume -= 0.5
            } else if initialVolume < 0.4 {
                initialVolume += 0.5
            }

            audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
        } catch {
            print("Could not observe outputVolume ", error)
        }
    }
//
//    func stopListeningVolumeButton() {
//
//        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
//
//        volumeView.removeFromSuperview()
//        volumeView = nil
//    }
    
    func setVolume(_ volume: Float) {
        let volume = MPVolumeView(frame: .zero)
        volume.setVolumeThumbImage(UIImage(), for: UIControl.State())
        volume.isUserInteractionEnabled = false
        volume.alpha = 0.00001
        volume.showsRouteButton = false
        view.addSubview(volume)
    }
    
        func setVolumeLevel(_ volumeLevel: Float) {
            let volume = MPVolumeView(frame: .zero)
            guard let slider = volume.subviews.compactMap({ $0 as? UISlider }).first else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
                slider.value = volumeLevel
            }

            if slider.value >= 0.6 {
                slider.value -= 0.5
            } else if slider.value <= 0.4 {
                slider.value += 0.5
            }
    }

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


